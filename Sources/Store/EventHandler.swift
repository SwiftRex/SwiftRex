public protocol EventHandler {
    func dispatch(_ event: Event)
}
