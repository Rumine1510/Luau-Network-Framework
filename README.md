# LuauNetworkModule

A network module designed to **simplify and improve communication between client-server**.
This module also allows for **local communication**, and will **eliminate the need to create remote instances yourself**.

This module will **lower the amount of bandwidth** used when communicating between client-server when using it instead of RemoteEvent.
This effect will be more noticeable when firing multiple remote events at once. Unlike some other modules, it does not use multiple remote instances
but rather one RemoteEvent and RemoteFunction with an identification key that is generated automatically when you create a signal. This can
be more efficient than using multiple remotes when the data used by the key is lower, such as using a binary string as a key, or a number.

To check the amount of data sent between the client and server, you can use the performance tab in the studio.

### Usage Example:
