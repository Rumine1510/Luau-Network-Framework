# Network Framework

This is a network module designed to **simplify and improve communication between client-server**.
This module also allows for **local communication**, and will **eliminate the need to create remote instances yourself**.

This module will **lower the use of bandwidth** caused by firing remote event when communicating between client-server. This effect will be more
noticeable when firing multiple remote events at once or if you fire it often. In the end there is an image attached about the comparison in the
amount of data used.

If you compare it with other modules such as BridgeNet, this module is more optimized in the aspect of network.

There are multiple features such as ReplicatedStorage for the network, allowing you to have table that replicate to client.

To check the amount of data sent between the client and server, you can use the performance tab in the studio.

## Important notes:
 - This module doesn't decrease the amount of data in the argument you passed to the client/server, only the amount caused firing the remote event

# Tested in framework version 0.3

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
