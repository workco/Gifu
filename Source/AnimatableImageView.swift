import UIKit

/// A protocol for the AnimatavleImageView delegate
public protocol AnimatableImageViewDelegate: class {
  /// optional delegate method that it is called when an AnimatableImageView animation did stop
  func animatableImageViewAnimationDidStop(animatableImageView: AnimatableImageView)
}

public extension AnimatableImageViewDelegate {
  /// forces method to be optional
  func animatableImageViewAnimationDidStop(animatableImageView: AnimatableImageView) { }
}

/// A subclass of `UIImageView` that can be animated using an image name string or raw data.
public class AnimatableImageView: UIImageView {
  /// animatable image view delegate instance
  public weak var delegate: AnimatableImageViewDelegate?

  /// An `Animator` instance that holds the frames of a specific image in memory.
  var animator: Animator?

  /// A display link that keeps calling the `updateFrame` method on every screen refresh.
  lazy var displayLink: CADisplayLink = CADisplayLink(target: self, selector: #selector(updateFrame))

  /// Current loaded data
  public private(set) var loadedData: NSData?

  /// The size of the frame cache.
  public var framePreloadCount = 50

  /// The required number of times the GIF animation is to cycle though the image sequence before stopping. The default is __0__ that means repeating the animation indefinitely. __-1__ means using loop count setting extracted from the GIF data.
  public var maxLoopCount = 0

  /// Specifies the number of times the animation has been looped.
  public private(set) var currentLoopCount = 0

  /// Specifies whether the GIF frames should be pre-scaled to save memory. Default is **true**.
  public var needsPrescaling = true

  /// A computed property that returns whether the image view is animating.
  public var isAnimatingGIF: Bool {
    return !displayLink.paused
  }

  /// A computed property that returns the total number of frames in the GIF.
  public var frameCount: Int {
    return animator?.frameCount ?? 0
  }

  /// Prepares the frames using a GIF image file name, without starting the animation.
  /// The file name should include the `.gif` extension.
  ///
  /// - parameter imageName: The name of the GIF file. The method looks for the file in the app bundle.
  public func prepareForAnimation(imageNamed imageName: String) {
    currentLoopCount = 0
    let imagePath = NSBundle.mainBundle().bundleURL.URLByAppendingPathComponent(imageName)
    prepareForAnimation <^> NSData(contentsOfURL: imagePath)
  }

  /// Prepares the frames using raw GIF image data, without starting the animation.
  ///
  /// - parameter data: GIF image data.
  public func prepareForAnimation(imageData data: NSData) {
    loadedData = data
    image = UIImage(data: data)
    animator = Animator(data: data, size: frame.size, contentMode: contentMode, framePreloadCount: framePreloadCount)
    animator?.needsPrescaling = needsPrescaling
    animator?.prepareFrames()
    attachDisplayLink()
  }

  /// Prepares the frames using a GIF image file name and starts animating the image view.
  ///
  /// - parameter imageName: The name of the GIF file. The method looks for the file in the app bundle.
  public func animateWithImage(named imageName: String) {
    prepareForAnimation(imageNamed: imageName)
    startAnimatingGIF()
  }

  /// Prepares the frames using raw GIF image data and starts animating the image view.
  ///
  /// - parameter data: GIF image data.
  public func animateWithImageData(data: NSData) {
    prepareForAnimation(imageData: data)
    startAnimatingGIF()
  }

  /// Updates the `image` property of the image view if necessary. This method should not be called manually.
  override public func displayLayer(layer: CALayer) {
    image = animator?.currentFrame
    stopAnimatingIfNeeded()
  }

  /// Starts the image view animation.
  public func startAnimatingGIF() {
    if animator?.isAnimatable ?? false {
      displayLink.paused = false
    }
  }

  /// Stops the image view animation.
  public func stopAnimatingGIF() {
    displayLink.paused = true
  }

  /// Reset the image view values
  public func prepareForReuse() {
    stopAnimatingGIF()
    animator = nil
  }

  /// Stops the animation in accordance with the loop count settings.
  func stopAnimatingIfNeeded() {
    guard let animator = animator where animator.currentAnimationPosition == animator.frameCount - 1 else {
      return
    }

    currentLoopCount += 1
    if shouldStopLooping() {
      currentLoopCount = 0
      stopAnimatingGIF()

      NSOperationQueue.mainQueue().addOperationWithBlock { [weak self] in
        guard let strongSelf = self else {
          return
        }

        strongSelf.delegate?.animatableImageViewAnimationDidStop(strongSelf)
      }
    }
  }

  /// Specifies whether all of the required animation iterations have been finished.
  /// - returns: true if the animation should stop looping, false otherwise.
  func shouldStopLooping() -> Bool {
    return maxLoopCount > 0 && maxLoopCount == currentLoopCount
  }

  /// Update the current frame with the displayLink duration
  func updateFrame() {
    if animator?.updateCurrentFrame(displayLink.duration) ?? false {
      layer.setNeedsDisplay()
    }
  }

  /// Invalidate the displayLink so it releases this object.
  deinit {
    displayLink.invalidate()
  }

  /// Attaches the display link.
  func attachDisplayLink() {
    displayLink.addToRunLoop(.mainRunLoop(), forMode: NSRunLoopCommonModes)
  }
}

