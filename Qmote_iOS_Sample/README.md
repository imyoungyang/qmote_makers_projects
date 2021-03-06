iOS Sample app
==============
This sample code will help developer integrate self app with Qmote hardware.
In this app, you will learn how to connect, write command and read device info with Qmote.
With this app, the original Qblinks Qmote app could use at the same time, it won't affect connection to each other.

Qmote GATT specification you could download [here](http://qblinks.com/devkit/developers/qmote-developers).
All command codes below you could find them in this document, please read it first.

### Screenshot
![App screenshot](https://github.com/qblinks/qmote_makers_projects/blob/master/Qmote_iOS_Sample/Screenshot_0623.jpg?raw=true)

Let's Start
===========
### A.Scan&Connect
This method is using for a new Qmote and doesn't connected and paired in iOS's system setting. This method will scan all Qmote which are sending discovering signal around the iPhone. Scanning method will add peripheral object into a NSMutableArray and connect the first one.

### B.Connect Qmote in System
This button will scan the system setting list and get the first Qmote which has already connected and paired in system.
If you have many Qmote, please use a NSArray to maintain and get the specific Qmote by index number.

### Click label text
When you press the Qmote button, this label will show your press pattern and code.
Qmote does not sense long-click until a long-click function is added. That is to reduce long/short mis-judge if there isn't any long-click feature added. So in this sample app, we forced to send a long press command code to Qmote in Send_CMD2_Qmote() function.

### Keep-alive
If user doesn't press Qmote for a few seconds, Qmote will into sleep mode to save power and Qmote will disconnect from iPhone. This keep-alive command will extend the time. If you want Qmote keep waking up, we suggest that send this command every 30 seconds to Qmote in foreground.

### Get FW version
This function will help you learn how would get the Qmote FW version. Send a request command to Qmote and you will get the return value at QPS_Q1_CB_UUID characteristic. 

### Keep app in background
At some point, iOS will terminate/suspend your app in background. Apple provide a [document](https://developer.apple.com/library/ios/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html) that tell you how to wake up your app. By our testing, this method isn't stability.
CLLocationManager provide a method that could wake up app with location update. There are example codes in Appdelegate. This will wake up your app at uniform interval. To learn more about it at Apple [document](https://developer.apple.com/library/ios/documentation/UserExperience/Conceptual/LocationAwarenessPG/CoreLocation/CoreLocation.html).
