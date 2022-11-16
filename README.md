# NetworkModule

This is a network module designed to **simplify and improve communication between client-server**.
This module also allows for **local communication**, and will **eliminate the need to create remote instances yourself**.

This module will **lower the amount of bandwidth** used when communicating between client-server. The effect will be more noticeable when
firing multiple remote events at once. Unlike some other modules, this module does not use multiple remote instances but rather one RemoteEvent
and RemoteFunction with an identification key that is generated automatically when you create a signal. This can be more efficient than using
multiple remotes when the data used by the key is lower, such as using a binary string as a key, or a number. In the end there is an image
attached about the comparison in the amount of data used.

To check the amount of data sent between the client and server, you can use the performance tab in the studio.

## Usage Example:

### Server
```lua
local NetworkModule = require(game.ReplicatedStorage.NetworkModule)

local network = NetworkModule.Register("TestNetwork"):Init() -- creating TestNetwork and Initialising it.

network:CreateSignal("Signal1"):Connect(print) -- creating a signal and connect it to print function

network.Events.Signal1.OnInvoke = function(data) -- adding OnInvoke function to Signal1
    print(data)
    return "Received"
end

local signal2 = network:CreateSignal("Signal2") -- creating another signal

signal2:Connect(function() -- connecting it to a function
    print("Work")
end)
```

### Client
```lua
local NetworkModule = require(game.ReplicatedStorage.NetworkModule)

local network = NetworkModule.WaitForNetwork("TestNetwork"):Init() -- Getting TestNetwork and initialising it for client.

local signalParams = network.newSignalParams() -- Optional, you can also pass in nil for default parameter.

network.Events.Signal2:Connect(function() -- Signal created from the server will exist for client.
    print("This work")
end)

network:FireSignal("Signal2") -- Firing signal to server, there are multiple way to do this.

local something = network.Events.Signal1:Invoke(nil, "Bye") -- Using nil instead of signalParams will be default parameter.
print(something) -- value returned from server

network.Events.Signal1:Fire(signalParams, "Hello") -- Firing signal to server with argument being "Hello".
```

### output
```lua
This Work -- client
Bye -- server
Work -- server
Received -- client
Hello -- server
```

There are a lot more API but since this is a private module, I will just cover the basic one. Maybe I'll add more info later.
In the future, this module might be public but currently, it seems too messy and I will probably have to improve it first.

Oh, here are some stats from the performance tab about the data being sent between client-server in case you want to check it out.

## Single remote event with identification key
![image](https://user-images.githubusercontent.com/105923121/202156149-5b55227f-5874-451c-bacd-bf21b03f7351.png)

## Network module
![image](https://user-images.githubusercontent.com/105923121/202156237-fec4e4cc-0422-4b75-8783-6ac9ce570c16.png)



## Multiple remote event with data
![image](https://user-images.githubusercontent.com/105923121/202156331-01ee7c7f-dca0-44e1-9640-11cdefe68548.png)

## Network module with data
![image](https://user-images.githubusercontent.com/105923121/202156509-aae4c162-a33e-4869-aa45-ab408a4917d6.png)

So, in conclusion about the performance:
    NetworkModule > Multiple RemoteEvent > Single RemoteEvent + Identification key

As you can see, by using this module, the amount of data being sent is lowered. This is not very noticeable unless you fire a lot of remotes at once,
so in the aspect of lowering the bandwidth, this may not be the best. In the future, the performance will be improved and more adjustable.
This is just the early version of the module.

This is all for now, maybe I will write more later.
