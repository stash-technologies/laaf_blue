# BLUE

A Flutter plugin for interfacing with LAAF liners, and an example flutter application demonstrating its usage.  
Version 0.0.2 covers
    scanning
    connection, reset, disconnection, and livestreaming data (steps and fsrs).  

# A Bird's Eye View (to get you started)

This is a bird's eye view of the plugin and its example app.  

First, make sure that your app has the right permissions for bluetooth on IOS (in the info.plist file).

 -> Privacy - Bluetooth always usage description
 -> Privacy - Bluetooth Peripheral usage description

 and 'Required Background Modes' -> App Comunicates with corebluetooth
 and under 'Signing and Certificates' you have to check 'Uses Bluetooth LE accessories...'

Now let's hop in to the example app.  

## The Example App

Beginning in 'main.dart', we instantiate the blue plugin (:22) [I'm going to use this shorthand for line numbers].  Then, we 'initializeBluetooth()', which will allow us to access bluetooth, and also update the current state of bluetooth (is it enabled?).  The result of this function will appear in the 
'_bluePlugin.blueState.bluetoothStatus' observable, which we will cover shortly.  Finally the 'blue' instance ('_bluePlugin') is passed to the PageManager, which is in charge of deciding which of the two pages in this app (ScanPage or CommandPage) should be showing, and also giving each of them what they need. 

In case it is unfamiliar I will quickly introduce the Observable (in the form that it appears in this plugin).  The idea behind the Observable class is that its instance holds some piece of data that will change over the life of the program, and some piece of the application would like to know when that change happens, and what that data changes to. In this case it is the PageManager that wants to know about the '...bluetoothStatus', which will indicate whether or not bluetooth is available (for instance, perhaps because the user turned it off).  So, the PageManager will use the blue plugin instance to access this observable, and it will register a unique key, and a callback function that takes the new data as an argument (through the observable's '.observeChanges' method).  Now this callback will be called anytime that the observable's data changes (and in this case, PageManager will update it's state).  When the PageManager is disposed, or no longer wants to listen to those changes, it must call the observable's '.removeRelevantObservers' method, passing the key that it registered earlier.  Back to the code.  

_PageManagerState's 'initState()' function is our first example of interacting with the Observable design pattern.  In 'attachObservers', the PageManager observes the various pieces of '...blueState' that it cares about ('bluetoothStatus', 'activeDevices' and 'blueMessage').  It manages these connections in 'didUpdateWidget', removing the observers from the old widget, and attaching them anew in the new widget (see 'removeObservers' (:74)).  It also removes observers in its 'dispose' method. PageManager's flow is this: if bluetooth is available, and we have 'activeDevices' (this is where connected devices appear), then load the CommandPage, otherwise, load the ScanPage.

As long as you understand how the Observable design pattern works, the rest of the blue plugin's functionality should be straightforward (reach out to me with any questions, I know that one's own code can seem easily understandable to the one who wrote it, but can sometimes be unintelligible to someone else haha).  

Something to be aware of - sometimes after hot-restarting the application, connection seems to fail, hanging after 'checkMode', because something on the platform is confused (I can't remember the exact error, but basically it originates in the fact that hot-restarting doesn't clear ALL of the application's state).  But disconnecting and reconnecting usually solves the problem, or just restarting the application.  I've never had it happen in an app that wasn't in debug mode (post hot-restart is a state only achievable in a debugging context) so I just worked around it.  

