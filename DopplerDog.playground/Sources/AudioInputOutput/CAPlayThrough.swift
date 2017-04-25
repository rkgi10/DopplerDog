//
//  CAPlayThrough.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//

import AVFoundation
import AudioUnit;
import CoreAudio;
import AudioToolbox;




func mergeAudioBufferList(_ abl: UnsafeMutableAudioBufferListPointer, inNumberFrames: UInt32) -> [Float] {
    let umpab = abl.map({ return UnsafeMutableRawPointer($0.mData!).assumingMemoryBound(to: Float32.self) })
    var b = Array<Float>(repeating: 0, count: Int(inNumberFrames));
    for (i, _) in b.enumerated() {
        b[i] = umpab.reduce(Float(0), { (f: Float, ab: UnsafeMutablePointer<Float32>) -> Float in
            return f + ab[i];
        })
    }
    return b;
}

func makeBufferSilent(_ ioData: UnsafeMutableAudioBufferListPointer) {
    for buf in ioData {
        memset(buf.mData, 0, Int(buf.mDataByteSize));
    }
}

public typealias CAPlayThroughCallback = (
    _ timeStamp : Double,
    _ numberOfFrames : Int,
    _ samples : [Float]
    ) -> Void

public class CAPlayThrough {
    
    
    
    var inputUnit: AudioUnit? = nil;
    var inputBuffer = UnsafeMutableAudioBufferListPointer(nil);
    var inputDevice: AudioDevice!;
    var outputDevice: AudioDevice!;
    
    var buffer = CARingBuffer();
    var bufferManager: BufferManager!;
    var dcRejectionFilter: DCRejectionFilter!;
    
    // AudioUnits and Graph
    var graph: AUGraph? = nil;
    var varispeedNode: AUNode = 0;
    var varispeedUnit: AudioUnit? = nil;
    var outputNode: AUNode = 0;
    var outputUnit: AudioUnit? = nil;
    
    // Buffer sample info
    var firstInputTime: Float64 = -1;
    var firstOutputTime: Float64 = -1;
    var inToOutSampleOffset: Float64 = 0;
    public var numberOfChannels: Int = 1
    /// When true, performs DC offset rejection on the incoming buffer before invoking the audioInputCallback.
    var shouldPerformDCOffsetRejection: Bool = false
    var recordingStartedCallback : CAPlayThroughCallback
    var sampleRate: Float = 44100.0


    
    var outputProc: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
//        print("output callback called")
        let This = Unmanaged<CAPlayThrough>.fromOpaque(inRefCon).takeUnretainedValue()
        var rate : Float64 = 0.0;
        var inTS = AudioTimeStamp();
        var outTS = AudioTimeStamp();
        let abl = UnsafeMutableAudioBufferListPointer(ioData)
        
        if (This.firstInputTime < 0) {
            // input hasn't run yet -> silence
            makeBufferSilent (abl!);
            return noErr;
        }
        
        // use the varispeed playback rate to offset small discrepancies in sample rate
        // first find the rate scalars of the input and output devices
        // this callback may still be called a few times after the device has been stopped
        if (AudioDeviceGetCurrentTime(This.inputDevice.id, &inTS) != noErr) {
            makeBufferSilent (abl!);
            return noErr;
        }
        
        if let err = checkErr(AudioDeviceGetCurrentTime(This.outputDevice.id, &outTS)) {
            return err;
        }
        
        rate = inTS.mRateScalar / outTS.mRateScalar;
        if let err = checkErr(AudioUnitSetParameter(This.varispeedUnit!, kVarispeedParam_PlaybackRate, kAudioUnitScope_Global, 0, AudioUnitParameterValue(rate), 0)) {
            return err;
        }
        
        // get Delta between the devices and add it to the offset
        if (This.firstOutputTime < 0) {
            This.firstOutputTime = inTimeStamp.pointee.mSampleTime;
            let delta = (This.firstInputTime - This.firstOutputTime);
            This.computeThruOffset();
            // changed: 3865519 11/10/04
            if (delta < 0.0) {
                This.inToOutSampleOffset -= delta;
            } else {
                This.inToOutSampleOffset = -delta + This.inToOutSampleOffset;
            }
            
            makeBufferSilent (abl!);
            return noErr;
        }
        
        // copy the data from the buffers
        let err = This.buffer.fetch(abl!, nFrames: inNumberFrames, startRead: Int64(inTimeStamp.pointee.mSampleTime - This.inToOutSampleOffset));
        if (err != CARingBufferError.ok) {
            makeBufferSilent (abl!);
            var bufferStartTime : Int64 = 0;
            var bufferEndTime : Int64 = 0;
            This.buffer.getTimeBounds(startTime: &bufferStartTime, endTime: &bufferEndTime);
            This.inToOutSampleOffset = inTimeStamp.pointee.mSampleTime - Float64(bufferStartTime);
        }
        
        return noErr;
        
    }
    
    var inputProc: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        
        let This = Unmanaged<CAPlayThrough>.fromOpaque(inRefCon).takeUnretainedValue()
        if (This.firstInputTime < 0) {
            This.firstInputTime = inTimeStamp.pointee.mSampleTime;
        }
        
        // Get the new audio data
        if let err = checkErr(AudioUnitRender(This.inputUnit!, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, (This.inputBuffer?.unsafeMutablePointer)!)) {
            return err;
        }
        
        // Move samples from mData into our native [Float] format.
        var samples = mergeAudioBufferList(This.inputBuffer!, inNumberFrames: inNumberFrames);
        
        if (This.bufferManager.needsNewFFTData > 0) {
            This.dcRejectionFilter.processInplace(&samples);
            This.bufferManager.copyAudioDataToFFTInputBuffer(samples);
        }
        // Not compatible with Obj-C...
        This.recordingStartedCallback(inTimeStamp.pointee.mSampleTime / Double(This.sampleRate),
                                      Int(inNumberFrames),
                                      samples)

        let ringBufferErr = This.buffer.store(This.inputBuffer!, framesToWrite: inNumberFrames, startWrite: CARingBuffer.SampleTime(inTimeStamp.pointee.mSampleTime))
        
        return ringBufferErr.toOSStatus();
        
    }
    private let recordingCallback: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        let audioip = Unmanaged<CAPlayThrough>.fromOpaque(inRefCon).takeUnretainedValue()
        //        let audioInput = unsafeBitCast(inRefCon, to: CAPlayThrough.self)
        var osErr: OSStatus = 0
        
        // We've asked CoreAudio to allocate buffers for us, so just set mData to nil and it will be populated on AudioUnitRender().
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: UInt32(audioip.numberOfChannels),
                mDataByteSize: 4,
                mData: nil))
        
        osErr = AudioUnitRender(audioip.inputUnit!,
                                ioActionFlags,
                                inTimeStamp,
                                inBusNumber,
                                inNumberFrames,
                                &bufferList)
        assert(osErr == noErr, "*** AudioUnitRender err \(osErr)")
        
        // Move samples from mData into our native [Float] format.
        var monoSamples = [Float]()
        let ptr = bufferList.mBuffers.mData?.assumingMemoryBound(to: Float.self)
        monoSamples.append(contentsOf: UnsafeBufferPointer(start: ptr, count: Int(inNumberFrames)))
        
        if audioip.shouldPerformDCOffsetRejection {
            DCRejectionFilterProcessInPlace(&monoSamples, count: Int(inNumberFrames))
        }
        
        // Not compatible with Obj-C...
        audioip.recordingStartedCallback(inTimeStamp.pointee.mSampleTime / Double(audioip.sampleRate),
                                         Int(inNumberFrames),
                                         monoSamples)
//        print("Audio callback called")
        return 0
    }

    
    
    public init(input: AudioDeviceID, output: AudioDeviceID,  callback : @escaping CAPlayThroughCallback) {
//        print("initialising CAPlaythrough")
        // Note: You can interface to input and output devices with "output" audio units.
        // Please keep in mind that you are only allowed to have one output audio unit per graph (AUGraph).
        // As you will see, this sample code splits up the two output units.  The "output" unit that will
        // be used for device input will not be contained in a AUGraph, while the "output" unit that will
        // interface the default output device will be in a graph.
        self.recordingStartedCallback = callback
            // Setup AUHAL for an input device
        if let _ = checkErr(setupAUHAL(input)) {
            exit(1);
        }
        
        // Setup Graph containing Varispeed Unit & Default Output Unit
        if let _ = checkErr(setupGraph(output)) {
            exit(1);
        }
        
        if let _ = checkErr(setupBuffers()) {
            exit(1);
        }
        
        // the varispeed unit should only be conected after the input and output formats have been set
//            if let _ = checkErr(AUGraphConnectNodeInput(graph!, varispeedNode, 0, outputNode, 0)) {
//                exit(1);
//            }
        
        if let _ = checkErr(AUGraphInitialize(graph!)) {
            exit(1);
        }
        
        // Add latency between the two devices
        computeThruOffset();
    }
    
    
    deinit {
//        print("deinitialising CAPlaythrough")
        cleanup()
    }
    
    public func startRecording() ->OSStatus
    {
//        print("hope it starts recording now")
        if let err = checkErr(AudioOutputUnitStart(inputUnit!)) {
            return err;
        }
        if let err = checkErr(AUGraphStart(graph!)) {
            return err;
        }
        return noErr
    }
    
    func getInputDeviceID()	-> AudioDeviceID { //print("getting input device id"); 
        return inputDevice.id;	}
    func getOutputDeviceID() -> AudioDeviceID {//print("getting output device id"); 
        return outputDevice.id; }
    
    func cleanup() {
        print("cleaning up CAPlaythrough")
        stop();
        
        if inputBuffer?.unsafePointer != nil {
            free(inputBuffer?.unsafeMutablePointer)
        }
    }
    
    @discardableResult
    func start() -> OSStatus {
//        print("started")
        if isRunning() {
            return noErr;
        }
        // Start pulling for audio data
        if let err = checkErr(AudioOutputUnitStart(inputUnit!)) {
            return err;
        }
        
        if let err = checkErr(AUGraphStart(graph!)) {
            return err;
        }
        
        // reset sample times
        firstInputTime = -1;
        firstOutputTime = -1;
        
        return noErr;
    }
    
    @discardableResult
    func stop() -> OSStatus {
//        print("stopped")
        if !isRunning() {
            return noErr;
        }
        if let err = checkErr(AudioOutputUnitStop(inputUnit!)) {
            return err;
        }
        if let err = checkErr(AUGraphStop(graph!)) {
            return err;
        }
        firstInputTime = -1;
        firstOutputTime = -1;
        return noErr;
    }
    
    
    public func isRunning() -> Bool {
//        print("checked is Running or not")
        var auhalRunning : UInt32 = 0;
        
        var graphRunning : DarwinBoolean = false;
        var size : UInt32 = UInt32(MemoryLayout<UInt32>.size);
        if (inputUnit != nil) {
            if let _ = checkErr(AudioUnitGetProperty(inputUnit!, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &auhalRunning, &size)) {
                return false;
            }
        }
        
        if (graph != nil) {
            if let _ = checkErr(AUGraphIsRunning(graph!, &graphRunning)) {
                return false;
            }
        }
        return (auhalRunning > 0 || graphRunning.boolValue);
    }
    
    func setOutputDeviceAsCurrent(_ out: AudioDeviceID) -> OSStatus {
//        print("set output device as current")
        var out = out
        var size = UInt32(MemoryLayout<AudioDeviceID>.size);
        
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        );
        
        if (out == kAudioDeviceUnknown) {
            if let err = checkErr(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &theAddress, 0, nil,
                                                             &size, &out)) {
                return err;
            }
        }
        outputDevice = AudioDevice(devid: out, isInput: false);
        
        // Set the Current Device to the Default Output Unit.
        return AudioUnitSetProperty(outputUnit!, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                    &outputDevice.id, UInt32(MemoryLayout<AudioDeviceID>.size));
    }
    
    func setInputDeviceAsCurrent(_ input: AudioDeviceID) -> OSStatus {
//        print("set input device as current")
        var input = input
        var size = UInt32(MemoryLayout<AudioDeviceID>.size);
        
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        );
        
        if (input == kAudioDeviceUnknown) {
            if let err = checkErr(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &theAddress, 0, nil,
                                                             &size, &input)) {
                return err;
            }
        }
        inputDevice = AudioDevice(devid: input, isInput: true);
        
        // Set the Current Device to the AUHAL.
        // this should be done only after IO has been enabled on the AUHAL.
        if let err = checkErr(AudioUnitSetProperty(inputUnit!, kAudioOutputUnitProperty_CurrentDevice,
                                                   kAudioUnitScope_Global, 0, &inputDevice.id,
                                                   UInt32(MemoryLayout<AudioDeviceID>.size))) {
            return err;
        }
        return noErr;
    }
    
    func setupGraph(_ out: AudioDeviceID) -> OSStatus {
//        print("setting up graph")
        // Make a New Graph
        if let err = checkErr(NewAUGraph(&graph)) {
            return err;
        }
        
        // Open the Graph, AudioUnits are opened but not initialized
        if let err = checkErr(AUGraphOpen(graph!)) {
            return err;
        }
        
        if let err = checkErr(makeGraph()) {
            return err;
        }
        if let err = checkErr(setOutputDeviceAsCurrent(out)) {
            return err;
        }
        
        // Tell the output unit not to reset timestamps
        // Otherwise sample rate changes will cause sync los
        var startAtZero : UInt32 = 0;
        if let err = checkErr(AudioUnitSetProperty(outputUnit!, kAudioOutputUnitProperty_StartTimestampsAtZero,
                                                   kAudioUnitScope_Global, 0, &startAtZero, UInt32(MemoryLayout<UInt32>.size))) {
            return err;
        }
        
        
        var output = AURenderCallbackStruct(
            inputProc: outputProc,
            inputProcRefCon: UnsafeMutableRawPointer(Unmanaged<CAPlayThrough>.passUnretained(self).toOpaque())
        );
        
        if let err = checkErr(AudioUnitSetProperty(varispeedUnit!, kAudioUnitProperty_SetRenderCallback,
                                                   kAudioUnitScope_Input, 0, &output, UInt32(MemoryLayout<AURenderCallbackStruct>.size))) {
            return err;
    }
    return noErr;
    }
    
    func makeGraph() -> OSStatus {
//        print("making graph")
        var varispeedDesc = AudioComponentDescription();
        var outDesc = AudioComponentDescription();
        
        // Q:Why do we need a varispeed unit?
        // A:If the input device and the output device are running at different sample rates
        // we will need to move the data coming to the graph slower/faster to avoid a pitch change.
        varispeedDesc.componentType = kAudioUnitType_FormatConverter;
        varispeedDesc.componentSubType = kAudioUnitSubType_Varispeed;
        varispeedDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        varispeedDesc.componentFlags = 0;
        varispeedDesc.componentFlagsMask = 0;
        
        outDesc.componentType = kAudioUnitType_Output;
        outDesc.componentSubType = kAudioUnitSubType_DefaultOutput;
        outDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        outDesc.componentFlags = 0;
        outDesc.componentFlagsMask = 0;
        
        //////////////////////////
        /// MAKE NODES
        // This creates a node in the graph that is an AudioUnit, using
        // the supplied ComponentDescription to find and open that unit
        if let err = checkErr(AUGraphAddNode(graph!, &varispeedDesc, &varispeedNode)) {
            return err;
        }
        if let err = checkErr(AUGraphAddNode(graph!, &outDesc, &outputNode)) {
            return err;
        }
        
        // Get Audio Units from AUGraph node
        if let err = checkErr(AUGraphNodeInfo(graph!, varispeedNode, nil, &varispeedUnit)) {
            return err;
        }
        
        if let err = checkErr(AUGraphNodeInfo(graph!, outputNode, nil, &outputUnit)) {
            return err;
        }
        
        // don't connect nodes until the varispeed unit has input and output formats set
        
        return noErr;
    }
    
    func setupAUHAL(_ input: AudioDeviceID) -> OSStatus {
//        print("setting up AUHAL")
        var comp : AudioComponent?;
        var desc = AudioComponentDescription();
        
        // There are several different types of Audio Units.
        // Some audio units serve as Outputs, Mixers, or DSP
        // units. See AUComponent.h for listing
        desc.componentType = kAudioUnitType_Output;
        
        // Every Component has a subType, which will give a clearer picture
        // of what this components function will be.
        desc.componentSubType = kAudioUnitSubType_HALOutput;
        
        // all Audio Units in AUComponent.h must use
        // "kAudioUnitManufacturer_Apple" as the Manufacturer
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        
        // Finds a component that meets the desc spec's
        comp = AudioComponentFindNext(nil, &desc);
        if (comp == nil) {
            exit(-1);
        }
        
        // gains access to the services provided by the component
        if let err = checkErr(AudioComponentInstanceNew(comp!, &inputUnit)) {
            return err;
        }
        
        // AUHAL needs to be initialized before anything is done to it
        if let err = checkErr(AudioUnitInitialize(inputUnit!)) {
            return err;
        }
//        print("audio unit initialisation 1")
        
        if let err = checkErr(enableIO()) {
            return err;
        }
        
        if let err = checkErr(setInputDeviceAsCurrent(input)) {
            return err;
        }
        
        if let err = checkErr(callbackSetup()) {
            return err;
        }
        
        // Don't setup buffers until you know what the
        // input and output device audio streams look like.
        
        if let err = checkErr(AudioUnitInitialize(inputUnit!)) {
            return err;
        }
        return noErr;
    }
    
    func enableIO() -> OSStatus {
//        print("Enabling IO")
        var enableIO : UInt32 = 1;
        
        ///////////////
        // ENABLE IO (INPUT)
        // You must enable the Audio Unit (AUHAL) for input and disable output
        // BEFORE setting the AUHAL's current device.
        
        // Enable input on the AUHAL
        if let err = checkErr(AudioUnitSetProperty(inputUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, // input element
            &enableIO, UInt32(MemoryLayout<UInt32>.size))) {
            return err;
        }
        
        // disable Output on the AUHAL
        enableIO = 0;
        if let err = checkErr(AudioUnitSetProperty(inputUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, // output element
            &enableIO, UInt32(MemoryLayout<UInt32>.size))) {
            return err;
        }
        return noErr;
    }
    
    func callbackSetup() -> OSStatus {
//        print("callback has been set up")
        var input = AURenderCallbackStruct(
            inputProc: inputProc,
            inputProcRefCon: UnsafeMutableRawPointer(Unmanaged<CAPlayThrough>.passUnretained(self).toOpaque())
        );
        
        // Setup the input callback.
        if let err = checkErr(AudioUnitSetProperty(inputUnit!, kAudioOutputUnitProperty_SetInputCallback,
                                                   kAudioUnitScope_Global, 0, &input,
                                                   UInt32(MemoryLayout<AURenderCallbackStruct>.size))) {
            return err;
        }
        return noErr;
    }
    
    public func setupBuffers() -> OSStatus {
//        print("buffers have been setup")
        var bufferSizeFrames : UInt32 = 2048;
        var bufferSizeBytes : UInt32 = 0;
        
        var asbd = AudioStreamBasicDescription();
        var asbd_dev1_in = AudioStreamBasicDescription();
        var asbd_dev2_out = AudioStreamBasicDescription();
        var rate : Float64 = 0;
        
        //set buffer size to 2048
        if let err = checkErr(AudioUnitSetProperty(inputUnit!,
                             kAudioDevicePropertyBufferFrameSize,
                             kAudioUnitScope_Global,
                             0,
                             &bufferSizeFrames,UInt32(MemoryLayout<Float32>.size)))
        {
            return err;
        }
        // Get the size of the IO buffer(s)
        var propertySize = UInt32(MemoryLayout<UInt32>.size);
        if let err = checkErr(AudioUnitGetProperty(inputUnit!, kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0, &bufferSizeFrames, &propertySize)) {
            return err;
        }
//        print("****buffer size frames is \(bufferSizeFrames) ****")
        bufferSizeBytes = bufferSizeFrames * UInt32(MemoryLayout<Float32>.size);
        
        // Get the Stream Format (Output client side)
        propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size);
        if let err = checkErr(AudioUnitGetProperty(inputUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &asbd_dev1_in, &propertySize)) {
            return err;
        }
//         print("=====Input DEVICE stream format\n" );
//         print(asbd_dev1_in)
        
        // Get the Stream Format (client side)
        propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size);
        if let err = checkErr(AudioUnitGetProperty(inputUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, &propertySize)) {
            return err;
        }
//         print("=====current Input (Client) stream format\n");
//         print(asbd)
        
        // Get the Stream Format (Output client side)
        propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size);
        if let err = checkErr(AudioUnitGetProperty(outputUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &asbd_dev2_out, &propertySize)) {
            return err;
        }
//         print("=====Output (Device) stream format\n");
//         print(asbd_dev2_out)
        
        //////////////////////////////////////
        // Set the format of all the AUs to the input/output devices channel count
        // For a simple case, you want to set this to the lower of count of the channels
        // in the input device vs output device
        //////////////////////////////////////
//        asbd.mChannelsPerFrame = ((asbd_dev1_in.mChannelsPerFrame < asbd_dev2_out.mChannelsPerFrame) ? asbd_dev1_in.mChannelsPerFrame : asbd_dev2_out.mChannelsPerFrame);
//         print("Info: Input Device channel count=%ld\t Ouput Device channel count=%ld\n",asbd_dev1_in.mChannelsPerFrame,asbd_dev2_out.mChannelsPerFrame);
//         print("Info: CAPlayThrough will use %ld channels\n",asbd.mChannelsPerFrame);
        
        
        // We must get the sample rate of the input device and set it to the stream format of AUHAL
        propertySize = UInt32(MemoryLayout<Float64>.size);
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        );
        
        if let err = checkErr(AudioObjectGetPropertyData(inputDevice.id, &theAddress, 0, nil, &propertySize, &rate)) {
            return err;
        }
        
        var maxFramesPerSlice: UInt32 = 4096;
        
        if let err = checkErr(AudioUnitSetProperty(inputUnit!, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, UInt32(MemoryLayout<UInt32>.size))) {
            return err;
        }
        
        var propSize = UInt32(MemoryLayout<UInt32>.size);
        if let err = checkErr(AudioUnitGetProperty(inputUnit!, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, &propSize)) {
            return err;
        }
        
        bufferManager = BufferManager(inMaxFramesPerSlice: Int(maxFramesPerSlice), sampleRate: rate);
        dcRejectionFilter = DCRejectionFilter();
        
        asbd.mSampleRate = rate;
        propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size);
        
        // Set the new formats to the AUs...
        if let err = checkErr(AudioUnitSetProperty(inputUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, propertySize)) {
            return err;
        }
        
        if let err = checkErr(AudioUnitSetProperty(varispeedUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, propertySize)) {
            return err;
        }
        
        // Set the correct sample rate for the output device, but keep the channel count the same
        propertySize = UInt32(MemoryLayout<Float64>.size);
        
        if let err = checkErr(AudioObjectGetPropertyData(outputDevice.id, &theAddress, 0, nil, &propertySize, &rate)) {
            return err;
        }
        
        asbd.mSampleRate = rate;
        propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size);
        
        // Set the new audio stream formats for the rest of the AUs...
//        if let err = checkErr(AudioUnitSetProperty(varispeedUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &asbd, propertySize)) {
//            return err;
//        }
//        
//        if let err = checkErr(AudioUnitSetProperty(outputUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, propertySize)) {
//            return err;
//        }
        
        inputBuffer = AudioBufferList.allocate(maximumBuffers: Int(asbd.mChannelsPerFrame));
        
        for var buf in inputBuffer! {
            buf.mNumberChannels = 1;
            buf.mDataByteSize = bufferSizeBytes;
        }
        
        // Alloc ring buffer that will hold data between the two audio devices
        buffer = CARingBuffer();
        buffer.allocate(Int(asbd.mChannelsPerFrame), bytesPerFrame: asbd.mBytesPerFrame, capacityFrames: bufferSizeFrames * 20);
        
        return noErr;
    }
    
    func computeThruOffset() {
//        print("computing through offset")
        // The initial latency will at least be the safety offset's of the devices + the buffer sizes
        inToOutSampleOffset = Float64(inputDevice.safetyOffset + inputDevice.bufferSizeFrames + outputDevice.safetyOffset + outputDevice.bufferSizeFrames);
    }
}

public class CAPlayThroughHost {
    var streamListenerQueue: DispatchQueue!;
    var streamListenerBlock: AudioObjectPropertyListenerBlock!;
    var playThrough : CAPlayThrough!;
    var defaultCallback : CAPlayThroughCallback! = {
        (_,_,_) -> Void in
//        print("default callback")
    }
    
    public init(input: AudioDeviceID, output: AudioDeviceID) {
        createPlayThrough(input, output);
    }
    
    func createPlayThrough(_ input: AudioDeviceID, _ output: AudioDeviceID) {
//        playThrough = CAPlayThrough(input: input, output: output);
        playThrough = CAPlayThrough(input: input, output: output, callback: defaultCallback)
        streamListenerQueue = DispatchQueue(label: "com.CAPlayThough.StreamListenerQueue", attributes: []);
        addDeviceListeners(input);
    }
    
    func deletePlayThrough() {
        if playThrough == nil {
            return;
        }
        playThrough.stop();
        removeDeviceListeners(playThrough.getInputDeviceID());
        streamListenerQueue = nil;
        playThrough = nil;
    }
    
    func resetPlayThrough() {
        let input = playThrough.getInputDeviceID();
        let output = playThrough.getOutputDeviceID();
        
        deletePlayThrough();
        createPlayThrough(input, output);
        playThrough.start();
    }
    
    func playThroughExists() -> Bool {
        return (playThrough != nil) ? true : false;
    }
    
    @discardableResult
    func start() -> OSStatus {
        if playThrough != nil {
            return playThrough.start();
        }
        return noErr;
    }
    
    @discardableResult
    func stop() -> OSStatus {
        if playThrough != nil {
            return playThrough.stop();
        }
        return noErr;
    }
    
    func isRunning() -> Bool {
        if playThrough != nil {
            return playThrough.isRunning();
        }
        return false;
    }
    
    func addDeviceListeners(_ input: AudioDeviceID) {
        streamListenerBlock = { (inNumberAddresses: UInt32, inAddresses: UnsafePointer<AudioObjectPropertyAddress>) in
            self.resetPlayThrough();
        };
        
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMaster
        );
        
        // StreamListenerBlock is called whenever the sample rate changes (as well as other format characteristics of the device)
        var propSize : UInt32 = 0;
        if let _ = checkErr(AudioObjectGetPropertyDataSize(input, &theAddress, 0, nil, &propSize)) {
            return;
        }
        
        let streams = UnsafeMutablePointer<AudioStreamID>.allocate(capacity: Int(propSize));
        let streamsBuf = UnsafeMutableBufferPointer<AudioStreamID>(start: streams, count: Int(propSize) / MemoryLayout<AudioStreamID>.size);
        
        if let _ = checkErr(AudioObjectGetPropertyData(input, &theAddress, 0, nil, &propSize, streams)) {
            return;
        }
        
        for stream in streamsBuf {
            propSize = UInt32(MemoryLayout<UInt32>.size);
            theAddress.mSelector = kAudioStreamPropertyDirection;
            theAddress.mScope = kAudioObjectPropertyScopeGlobal;
            
            var isInput : UInt32 = 0;
            if let _ = checkErr(AudioObjectGetPropertyData(stream, &theAddress, 0, nil, &propSize, &isInput)) {
                continue;
            }
            if isInput == 0 {
                continue;
            }
            theAddress.mSelector = kAudioStreamPropertyPhysicalFormat;
            
            checkErr(AudioObjectAddPropertyListenerBlock(stream, &theAddress, streamListenerQueue, streamListenerBlock))
        }
        free(streams)
    }
    
    func removeDeviceListeners(_ input: AudioDeviceID) {
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMaster
        );
        
        var propSize : UInt32 = 0;
        if let _ = checkErr(AudioObjectGetPropertyDataSize(input, &theAddress, 0, nil, &propSize)) {
            return;
        }
        
        let streams = UnsafeMutablePointer<AudioStreamID>.allocate(capacity: Int(propSize));
        let streamsBuf = UnsafeMutableBufferPointer<AudioStreamID>(start: streams, count: Int(propSize) / MemoryLayout<AudioStreamID>.size);
        
        if let _ = checkErr(AudioObjectGetPropertyData(input, &theAddress, 0, nil, &propSize, streams)) {
            return;
        }
        
        for stream in streamsBuf {
            propSize = UInt32(MemoryLayout<UInt32>.size);
            theAddress.mSelector = kAudioStreamPropertyDirection;
            theAddress.mScope = kAudioObjectPropertyScopeGlobal;
            
            var isInput: UInt32 = 0;
            if let _ = checkErr(AudioObjectGetPropertyData(stream, &theAddress, 0, nil, &propSize, &isInput)) {
                continue;
            }
            if isInput == 0 {
                continue;
            }
            theAddress.mSelector = kAudioStreamPropertyPhysicalFormat;
            
            checkErr(AudioObjectRemovePropertyListenerBlock(stream, &theAddress, streamListenerQueue, streamListenerBlock));
            streamListenerBlock = nil;
        }
        free(streams)
    }
}

private func DCRejectionFilterProcessInPlace(_ audioData: inout [Float], count: Int) {
    
    let defaultPoleDist: Float = 0.975
    var mX1: Float = 0
    var mY1: Float = 0
    
    for i in 0..<count {
        let xCurr: Float = audioData[i]
        audioData[i] = audioData[i] - mX1 + (defaultPoleDist * mY1)
        mX1 = xCurr
        mY1 = audioData[i]
    }
}
