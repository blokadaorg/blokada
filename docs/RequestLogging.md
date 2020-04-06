# The RequestLog

## Overall structure off the RequestLog
The 'RequestLog'-class is responsible for keeping track of allowed and blocked domains,
allowing changes to recent requests after for example checking the response from the DNS-server and manages persistence of this data.
Persistence can be deactivated if the user wants so but will lead to some functionality being unavailable and slightly increased memory usage.
The class allows access to this information over 2 different ways depending what logs should be accessed:

### Instance of RequestLog
* A instance of the class has access to the complete saved log but not all of it is loaded all the time to save memory
* If a bigger portion of the log is needed a call to 'expandHistory()' will load another batch
* 'close()' should be called if the instance is no longer needed so the temporary loaded parts of the log can be discarded. -> lower memory usage.

### Companion-object
* The companion object of the class allows access to the last few requests which are always keept in memory.
* The adblocking-part calls 'add()' to add a new request to the log.
* Different parts of the app can use the 'update()'-functions to update info for requests in this part of the log.

## Usage of the log

### Hostlog
* The hostlog is the main usage of the RequestLog-class allowing the user to see what has been blocked or allowed.
* The data for the hostlog is saved in 3 batches with increasing size.

### Smartlist
* All domains that overflow from the last batch of the hostlog would normally be discarded.
* If smartlist is active these domains are logged as additional smartlist-batches.
* Every time the hostlog overflows into the smartlist log a new batch is created.
* These batches are only discarded once the learning phase of smartlist becomes active or smartlist is reset.

### CSV
* If the first batch of the hostlog overflows and this feature is active the domains are also logged in the CSV file

## The REQUEST_UPDATE-event
* This event allows every part to get notified when a new request is added or a existing one is updated
* For a newly added request the 'oldState' variable will be 'null' and the 'index' will be -1
* 'oldState' and 'newState' values in the event allow to check what changed

## The ExtendedRequest-data-class
This data class is used to store all data connected to a single request.
It has the following fields: 
* 'domain: String':
* 'time: Date = Date():'
* 'state: RequestState': Enum representing the current state of this request. Possible values are the following:
    * 'BLOCKED_NORMAL': blocked by blacklist
    * 'BLOCKED_CNAME': blocked by cname-check
    * 'BLOCKED_ANSWER': blocked by DNS-server
    * 'ALLOWED_APP_UNKNOWN': allowed app unknown
    * 'ALLOWED_APP_KNOWN': allowed app known ( future use )
* 'ip: InetAddress?': For future use
* 'appId: String?': For future use
