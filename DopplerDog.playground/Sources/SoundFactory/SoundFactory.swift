//
//  SoundFactory.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//
import AVFoundation

public class SoundFactory {
    
    let engine = AVAudioEngine()
    let tone = FrequencyGenerator()
    let format : AVAudioFormat
    let sampleRate = 44100.0
    var mixer : AVAudioMixerNode
    //    let frequency : Float
    //    let amplitude : Double
    
    public init(channels : Int, withFrequency frequency : Double, andAmplitude amplitude : Double, andVolume volume : Float) {
        format = AVAudioFormat(standardFormatWithSampleRate: tone.sampleRate, channels: AVAudioChannelCount(channels))
        tone.frequency = frequency
        tone.amplitude = amplitude
        engine.attach(tone)
        mixer = engine.mainMixerNode
        mixer.volume = volume
        engine.connect(tone, to: mixer, format: format)
    }
    
    public init(channels : Int, withFrequency frequency : Double, andAmplitude amplitude : Double, andVolume volume : Float, andPlay play : Bool) {
        format = AVAudioFormat(standardFormatWithSampleRate: tone.sampleRate, channels: AVAudioChannelCount(channels))
        tone.frequency = frequency
        tone.amplitude = amplitude
        engine.attach(tone)
        mixer = engine.mainMixerNode
        mixer.volume = volume
        engine.connect(tone, to: mixer, format: format)
        if play{
            self.play()
        }
    }//    let format = AVAudioFormat(standardFormatWithSampleRate: tone.sampleRate, channels: 2)
    
    public func play()
    {
        do {
            try self.engine.start()
            self.tone.preparePlaying()
            self.tone.play()
        } catch  {
            print("Tone playing error")
        }
    }
    public func play(Frequency frequency: Double,Amplitude amplitude: Double, andVolume volume : Float)
    {
        do {
            engine.mainMixerNode.volume = volume
            try engine.start()
            tone.frequency = frequency
            tone.amplitude = amplitude
            tone.preparePlaying()
            tone.play()
//            print("tone playing")
        } catch {
            print("tone playing error")
        }
    }
    public func stopPlaying()
    {
        engine.mainMixerNode.volume = 0.0
        engine.stop()
        tone.stop()
        print("Tone stopped")
    }
    
    //    engine.attach(tone)
    //    var mixer = engine.mainMixerNode
    //    engine.mainMixerNode.volume = 1.0
    
}
