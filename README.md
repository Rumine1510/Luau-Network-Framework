# Network Framework

This is a network module designed to **simplify and improve communication between client-server**.
This module also allows for **local communication**, and will **eliminate the need to create remote instances yourself**.

This module will **lower the use of bandwidth** caused by firing remote event when communicating between client-server. This effect will be especially more
noticeable when firing multiple remote events at once. Unlike some other modules, this module does not use multiple remote instances but rather
one RemoteEvent and RemoteFunction with an identification key that is generated automatically when you create a signal. This can be more efficient
than using multiple remotes when the data used by the key is lower, such as using a binary string as a key, or a number. In the end there is an image
attached about the comparison in the amount of data used.

To check the amount of data sent between the client and server, you can use the performance tab in the studio.

## Important notes:
 - This module doesn't decrease the amount of data in the argument you passed to the client/server, only the amount caused
   by using the identification key and firing the remote event

 - Signal can only be created from the server for the client to be able to communicate with the server with it. In the future,
   this may be adjustable.

## Usage Example:

### Server
```lua
local NetworkModule = require(game.ReplicatedStorage.NetworkModule)

local network = NetworkModule.Register("TestNetwork"):Init() -- creating TestNetwork and Initialising it.

local signalParams = network.newSignalParams() -- Optional, you can pass this in as a second argument in CreateSignal method but I won't be covering that.

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

network.Events.Signal2:Connect(function() -- Signal created from the server will exist for client, this behavior can be changed with signalParams.
    print("This work")
end)

network:FireSignal("Signal2") -- Firing signal to server, there are multiple way to do this.

local something = network.Events.Signal1:Invoke(nil, "Bye") -- Invoking server with "Bye" as an argument. Passing nil for default signal property.
print(something) -- value returned from server

network.Events.Signal1:Fire(nil, "Hello") -- Firing signal to server with argument being "Hello". Passing nil for default signal property.
```

### Output
```lua
This Work -- client
Bye -- server
Work -- server
Received -- client
Hello -- server
```

There are a lot more API but since this is a private module, I will just cover the basic one. Maybe I'll add more info later.
In the future, this module might be public but currently, it seems too messy and I will probably have to improve it first.

Oh, and here are some stats from the performance tab about the data being sent between client-server in case you want to check it out.

## Passing data at high rate

### Single remote event with identification key
Send kBps: 6.18e+03
![image](https://user-images.githubusercontent.com/105923121/202156149-5b55227f-5874-451c-bacd-bf21b03f7351.png)

### Network module
Send kBps: 761
![image](https://user-images.githubusercontent.com/105923121/202156237-fec4e4cc-0422-4b75-8783-6ac9ce570c16.png)

As you can see, using this network module pass way less data than remote event when firing at high rate.

## Passing data at lower rate

### Single remote event with identification key and small data
Send kbPS: 1.2e+04
![image](https://user-images.githubusercontent.com/105923121/202165769-bc749d01-1918-43eb-9155-9f752427c97b.png)

### Multiple remote event with small data
Send kBps: 1.1e+04
![image](https://user-images.githubusercontent.com/105923121/202156331-01ee7c7f-dca0-44e1-9640-11cdefe68548.png)

### Network module with small data
Send kBps: 9.71e+03
![image](https://user-images.githubusercontent.com/105923121/202156509-aae4c162-a33e-4869-aa45-ab408a4917d6.png)

So, in conclusion about the performance:
    NetworkModule > Multiple RemoteEvent > Single RemoteEvent + Identification key

As you can see, by using this module, the amount of data being sent by each remote event is lowered. This is not very noticeable unless you
fire a lot of remotes at once, so in the aspect of lowering the bandwidth, this may not be the best. In the future, the performance will be
improved and more adjustable. This is just the early version of the module.

This is all for now, maybe I will write more later.
