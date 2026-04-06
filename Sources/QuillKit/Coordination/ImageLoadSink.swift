protocol ImageLoadSink: AnyObject {
    @MainActor func apply(imageLoadResult: ImageLoadResult)
}
