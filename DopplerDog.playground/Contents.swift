/*:
 # Hi There !!
 */
//: ## This playground(macOs only) demonstrates Motion Sensing using Doppler Effect. Please plug out your headphones and keep the system speaker volume at maximum before executing this playground. This playground will not run properly with low volume or external speakers or headphones.
/*:
 ### We use a simple game to show the recognised gestures. Internally it works a bit like this :
 * Our computer generates a barely audible 20kHz sound wave...which after reflection from our surroundings, is received by the speaker
 * Whenever an object moves towards the mic of our computer, or away from it, we get a shift in the frequency of sound-wave received by the mic.
 * This apparent change of frequency is called **Doppler Effect**
 * For doppler effect to work. there must be enough relative motion between object and receiver(in this case, mic) either horizontal, or vertical.
 */

//: ### The game in this playground can be played with both the arrow keys and gestures(left and right movements). For gestures, there will be an initial 3-4 second delay, where gestures will not get recognised.

import Cocoa
import PlaygroundSupport
//: __Please move your hand within the region shown below on a macbook-pro__ for accurate gesture recognition. This playground has been tested on a macbook-pro only, and may perform weirdly on other devices.
let image = NSImage(named: "macbookpro.png")
//: For other (optional : not to be considered for WWDC Submissions) demos, try replacing gameWindow in the code below to __dopplerDemo__ or __spectralWindow__ and run the playground
PlaygroundPage.current.liveView = gameWindow
//: This game's window is 800x600. So please adjust your Xcode-view layout accordingly to get the optimal experience. Also this is best experienced on Macbook-Pro


