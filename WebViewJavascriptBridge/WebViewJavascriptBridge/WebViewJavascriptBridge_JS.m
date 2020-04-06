// This file contains the source for the Javascript side of the
// WebViewJavascriptBridge. It is plaintext, but converted to an NSString
// via some preprocessor tricks.
//
// Previous implementations of WebViewJavascriptBridge loaded the javascript source
// from a resource. This worked fine for app developers, but library developers who
// included the bridge into their library, awkwardly had to ask consumers of their
// library to include the resource, violating their encapsulation. By including the
// Javascript as a string resource, the encapsulation of the library is maintained.

#import "WebViewJavascriptBridge_JS.h"

NSString * WebViewJavascriptBridge_js() {
    // 宏定义中#号的意思是将参数字符传化
	#define __wvjb_js_func__(x) #x
	
	// BEGIN preprocessorJSCode
    // ;(function() {})()函数前面跟一个一元表达式会立即执行后面的匿名函数等价于(function(){})()
	static NSString * preprocessorJSCode = @__wvjb_js_func__(
;(function() {
    // 如果已经存在WebViewJavascriptBridge属性，则return
	if (window.WebViewJavascriptBridge) {
		return;
	}

	if (!window.onerror) {
		window.onerror = function(msg, url, line) {
			console.log("WebViewJavascriptBridge: ERROR:" + msg + "@" + url + ":" + line);
		}
	}
    // 生成WebViewJavascriptBridge属性，并挂载到window上
	window.WebViewJavascriptBridge = {
		registerHandler: registerHandler,
		callHandler: callHandler,
		disableJavscriptAlertBoxSafetyTimeout: disableJavscriptAlertBoxSafetyTimeout,
		_fetchQueue: _fetchQueue,
		_handleMessageFromObjC: _handleMessageFromObjC
	};

	var messagingIframe;
	var sendMessageQueue = [];
	var messageHandlers = {};
	
	var CUSTOM_PROTOCOL_SCHEME = 'https';
	var QUEUE_HAS_MESSAGE = '__wvjb_queue_message__';
	
	var responseCallbacks = {};
	var uniqueId = 1;
	var dispatchMessagesWithTimeoutSafety = true;

    // js注册供原生调用的方法
	function registerHandler(handlerName, handler) {
        // 保存html中注册的供原生调用的handlerName（方法名称）与handler（匿名函数），原生调用js会从messageHandlers中根据handlerName取handler
		messageHandlers[handlerName] = handler;
	}
	
    // js调用原生方法
	function callHandler(handlerName, data, responseCallback) {
        // 在 JavaScript 中 arguments 对象是比较特别的一个对象，实际上是当前函数的一个内置属性，它的长度是由实参个数而不是形参个数决定的。那么就很容易理解了，下面的代码是一个冗错处理，也就是说在调用 callHandler 的时候可以不传调用 native 方法中的data数据参数，只传递调用 nativie 方法中的方法名字和回调方法即可。
		if (arguments.length == 2 && typeof data == 'function') {
			responseCallback = data;
			data = null;
		}
		_doSend({ handlerName:handlerName, data:data }, responseCallback);
	}
    // 修改bool值，控制处理原生传过来json数据时同步 or 异步执行
	function disableJavscriptAlertBoxSafetyTimeout() {
		dispatchMessagesWithTimeoutSafety = false;
	}
	
    // js触发原生代理方法
	function _doSend(message, responseCallback) {
        // 判断js调用原生时，js是否有响应回调
		if (responseCallback) {
            // 创建回调id
			var callbackId = 'cb_'+(uniqueId++)+'_'+new Date().getTime();
            // 将callbackId (key) 与 响应回调（value）保存到 responseCallbacks
			responseCallbacks[callbackId] = responseCallback;
            // 将 字符串callbackId 与 callbackId值 保存到 message
			message['callbackId'] = callbackId;
		}
        // 将 message 保存到 sendMessageQueue，
		sendMessageQueue.push(message);
        // 修改 src，触发原生webview代理方法，调用下面的_fetchQueue()方法，从sendMessageQueue获取上一行代码保存的message
		messagingIframe.src = CUSTOM_PROTOCOL_SCHEME + '://' + QUEUE_HAS_MESSAGE;
	}

    // 原生获取js调用原生时保存到sendMessageQueue中的数据、
    // 原生获取原生调用js时js保存到sendMessageQueue中的响应回调数据
	function _fetchQueue() {
        // stringify()用于从一个对象解析出字符串
		var messageQueueString = JSON.stringify(sendMessageQueue);
        // sendMessageQueue置空
		sendMessageQueue = [];
		return messageQueueString;
	}

    // 处理原生传过来json数据
	function _dispatchMessageFromObjC(messageJSON) {
        // dispatchMessagesWithTimeoutSafety默认为true
		if (dispatchMessagesWithTimeoutSafety) {
            // 异步执行_doDispatchMessageFromObjC方法
			setTimeout(_doDispatchMessageFromObjC);
		} else {
            // 同步执行_doDispatchMessageFromObjC方法
			 _doDispatchMessageFromObjC();
		}
		
		function _doDispatchMessageFromObjC() {
            // 使用 JSON.parse 将 JSON 字符串转换为对象
			var message = JSON.parse(messageJSON);
			var messageHandler;
			var responseCallback;

			if (message.responseId) {
                // js调用原生，原生进行响应回调，执行这里
                // 获取js调用原生的响应回调函数并执行
				responseCallback = responseCallbacks[message.responseId];
				if (!responseCallback) {
					return;
				}
				responseCallback(message.responseData);
				delete responseCallbacks[message.responseId];
			} else {
                // 原生调用js，执行这里
                // 根据callbackId 判断原生是否存在响应回调
				if (message.callbackId) {
					var callbackResponseId = message.callbackId;
                    // 创建js对原生的响应回调函数
					responseCallback = function(responseData) {
						_doSend({ handlerName:message.handlerName, responseId:callbackResponseId, responseData:responseData });
					};
				}
				
                // 根据 handlerName 从 messageHandlers 中获取js端注册的方法回调
				var handler = messageHandlers[message.handlerName];
				if (!handler) {
					console.log("WebViewJavascriptBridge: WARNING: no handler for message from ObjC:", message);
				} else {
                    // 执行js端注册的供原生调用的方法的回调
					handler(message.data, responseCallback);
				}
			}
		}
	}
	
    // 处理原生传过来json数据
	function _handleMessageFromObjC(messageJSON) {
        // 调用_dispatchMessageFromObjC方法
        _dispatchMessageFromObjC(messageJSON);
	}

    // 创建一个iframe，并挂载到window上
	messagingIframe = document.createElement('iframe');
	messagingIframe.style.display = 'none';
	messagingIframe.src = CUSTOM_PROTOCOL_SCHEME + '://' + QUEUE_HAS_MESSAGE;
	document.documentElement.appendChild(messagingIframe);

    // 调用registerHandler方法 参数为字符串_disableJavascriptAlertBoxSafetyTimeout、函数disableJavscriptAlertBoxSafetyTimeout
	registerHandler("_disableJavascriptAlertBoxSafetyTimeout", disableJavscriptAlertBoxSafetyTimeout);
	
    // setTimeout():是异步的，在指定的毫秒数后，将定时任务处理的函数添加到执行队列的队尾。
	setTimeout(_callWVJBCallbacks, 0);
    // 遍历并执行html中WVJBCallbacks里的函数，并传入WebViewJavascriptBridge对象
	function _callWVJBCallbacks() {
		var callbacks = window.WVJBCallbacks;
		delete window.WVJBCallbacks;
		for (var i=0; i<callbacks.length; i++) {
            // 将WebViewJavascriptBridge作为参数，传入到WVJBCallbacks保存的方法中
			callbacks[i](WebViewJavascriptBridge);
		}
	}
})();
	); // END preprocessorJSCode

	#undef __wvjb_js_func__
	return preprocessorJSCode;
};
