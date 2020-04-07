//
//  ExampleWKWebViewController.m
//  ExampleApp-iOS
//
//  Created by Marcus Westin on 1/13/14.
//  Copyright (c) 2014 Marcus Westin. All rights reserved.
//

#import "ExampleWKWebViewController.h"
#import "WebViewJavascriptBridge.h"
#import "SSZipArchive.h"

@interface ExampleWKWebViewController ()

@property WebViewJavascriptBridge* bridge;

@end
@implementation ExampleWKWebViewController

- (void)viewWillAppear:(BOOL)animated {
    if (_bridge) { return; }
    
    // 为测试代码添加
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.preferences setValue:@(true) forKey:@"allowFileAccessFromFileURLs"];
    
    WKWebView* webView = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:self.view.bounds configuration:config];
    webView.navigationDelegate = self;
    webView.UIDelegate = self;
    [self.view addSubview:webView];
    
    [WebViewJavascriptBridge enableLogging];
    _bridge = [WebViewJavascriptBridge bridgeForWebView:webView];
    [_bridge setWebViewDelegate:self];
    
    [_bridge registerHandler:@"testObjcCallback" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"testObjcCallback called: %@", data);
        responseCallback(@"Response from testObjcCallback");
    }];
    
    [_bridge callHandler:@"testJavascriptHandler" data:@{ @"foo1":@"before ready" } responseCallback:^(id responseData) {
        NSLog(@"sss %@", responseData);
    }];
    
    [self unzipAction];
    [self renderButtons:webView];
    [self loadExamplePage:webView];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"webViewDidStartLoad");
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"webViewDidFinishLoad");
}



- (void)renderButtons:(WKWebView*)webView {
    UIFont* font = [UIFont fontWithName:@"HelveticaNeue" size:12.0];
    
    UIButton *callbackButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [callbackButton setTitle:@"Call handler" forState:UIControlStateNormal];
    [callbackButton addTarget:self action:@selector(callHandler:) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:callbackButton aboveSubview:webView];
    callbackButton.frame = CGRectMake(10, 400, 100, 35);
    callbackButton.titleLabel.font = font;
    
    UIButton* reloadButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [reloadButton setTitle:@"Reload webview" forState:UIControlStateNormal];
    [reloadButton addTarget:webView action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:reloadButton aboveSubview:webView];
    reloadButton.frame = CGRectMake(110, 400, 100, 35);
    reloadButton.titleLabel.font = font;
}

- (void)callHandler:(id)sender {
    id data = @{ @"greetingFromObjC": @"Hi there, JS!" };
    [_bridge callHandler:@"testJavascriptHandler" data:data responseCallback:^(id response) {
        NSLog(@"testJavascriptHandler responded: %@", response);
    }];
}

- (void)unzipAction {
    NSString *zipPath = [[NSBundle mainBundle] pathForResource:@"html" ofType:@"zip"];
    NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    BOOL isSuccess = [SSZipArchive unzipFileAtPath:zipPath toDestination:document];
    NSLog(@"解压缩： %@", isSuccess ? @"成功" : @"失败");
}

- (void)loadExamplePage:(WKWebView*)webView {
//    原代码
    NSString* htmlPath = [[NSBundle mainBundle] pathForResource:@"ExampleApp" ofType:@"html"];
    NSString* appHtml = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
    [webView loadHTMLString:appHtml baseURL:baseURL];
    
    
//    测试代码
//    html放在程序内部
//    添加方式 create folder referencess 可以
//    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"html" inDirectory:@"123"];
//    NSURL *pathURL = [NSURL fileURLWithPath:filePath];
//    if (@available(iOS 9.0, *)) {
//        [webView loadFileURL:[NSURL fileURLWithPath:filePath] allowingReadAccessToURL:[NSURL fileURLWithPath:[NSBundle mainBundle].bundlePath]];
//    }
    
    
//    添加方式 create groups 经测试不行 图片、css、js引用不上
//    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"];
//    NSData *htmlData = [[NSData alloc] initWithContentsOfFile:htmlPath];
//    NSURL *bundleUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle]bundlePath]];
//    [webView loadData:htmlData MIMEType:@"text/html" characterEncodingName:@"UTF-8" baseURL:bundleUrl];
    
    
//    html放在document下 html与js/css/图片等资源同目录、或html位于js/css/图片等资源路径的上层目录、html与js/css/图片等资源位于不同路径下
//    如：方式一
//       ---html
//       ----js1.js
//       ----css1.css
//       ----image1.png
//       ----html1.html
//    如：方式二
//       ---html
//       ----JS
//       ------js1.js
//       ----CSS
//       ------css1.css
//       ----Image
//       ------image1.png
//       ----html1.html
//    如：方式三
//       ---html
//       ----JS
//       ------js1.js
//       ----CSS
//       ------css1.css
//       ----Image
//       ------image1.png
//       ----Html
//       ------html1.html
    
    
//    方式一、二可以、方式三不不行 图片、css、js引用不上
//    NSString *document = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
//    NSString *path = [document stringByAppendingString:@"html/test.html"];
//    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]]];
    
//    NSString *document = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
//    NSString *htmlPath = [document stringByAppendingString:@"/html/Html/test.html"];
//    NSData *htmlData = [[NSData alloc] initWithContentsOfFile:htmlPath];
//    NSString *htmlStr = [[NSString alloc] initWithData:htmlData encoding:NSUTF8StringEncoding];
    
    
//    方式三 经测试不行 图片、css、js引用不上
//    NSURL *baseURL = [NSURL fileURLWithPath:[document stringByAppendingString:@"/html/"]];
//    [webView loadHTMLString:htmlStr baseURL:baseURL];
    
    
//  方式三 可以
//    NSError *error;
//    BOOL isSuccess = [htmlStr writeToFile:[document stringByAppendingString:@"/html/Html/syl.html"] atomically:YES encoding:NSUTF8StringEncoding error:&error];
//    if (isSuccess && !error) {
//        NSURL *baseURL = [NSURL fileURLWithPath:[document stringByAppendingString:@"/html/"]];
//        [webView loadFileURL:[NSURL fileURLWithPath:[document stringByAppendingString:@"/html/Html/syl.html"]] allowingReadAccessToURL:baseURL];
//    }
    
  
//    方式三 经测试不行 图片、css、js引用不上
//    NSURL *baseURL = [NSURL fileURLWithPath:[document stringByAppendingString:@"/html/"]];
//    [webView loadData:htmlData MIMEType:@"text/html" characterEncodingName:@"UTF-8" baseURL:baseURL];
}

-(void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(nonnull NSString *)message initiatedByFrame:(nonnull WKFrameInfo *)frame completionHandler:(nonnull void (^)(void))completionHandler
{
    NSLog(@"123 : %@", message);
    completionHandler();
}

@end
