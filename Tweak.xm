#import "Tweak.h"
#import "Headers.h"

NSBundle *bundle = [NSBundle mainBundle];
NSString *bunlde_id = [bundle bundleIdentifier];
NSString *plist_path = [NSString stringWithFormat:@"%@/Library/Preferences/%@.plist", NSHomeDirectory(), bunlde_id]; \

inline NSMutableDictionary* getPref(NSString* plugin_name){
	// NSLog(@"%@", plist_path)
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:plist_path];
	if ([prefs objectForKey:@"enmity"] && [[prefs objectForKey:@"enmity"] objectForKey:plugin_name]){
		return [[prefs objectForKey:@"enmity"] objectForKey:plugin_name];
	}
	return nil;
}

/* Enmity comannd handling: https://github.com/enmity-mod/tweak/blob/main/src/Commands.x */
// Create a response to a command
NSDictionary* createResponse(NSString *uuid, NSString *data) {
	NSDictionary *response = @{
		@"id": uuid,
		@"data": data
	};
	return response;
}

// Send a response back
void sendResponse(NSDictionary *response) {
	NSError *err;
	NSData *data = [NSJSONSerialization
	                dataWithJSONObject:response
	                options:0
	                error:&err];
	if (err) {
		return;
	}
	NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSString *responseString = [NSString stringWithFormat: @"%@%@", ENMITY_PROTOCOL, [json stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
	NSURL *url = [NSURL URLWithString:responseString];
	[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

// Validate that a command is using the Enmity scheme
BOOL validateCommand(NSString *command) {
	BOOL valid = [command containsString:@"enmity"];
	return valid;
}

// Clean the received command
NSString* cleanCommand(NSString *command) {
	NSString *json = [[command stringByReplacingOccurrencesOfString:ENMITY_PROTOCOL withString:@""] stringByRemovingPercentEncoding];
	return json;
}

// Parse the command
NSDictionary* parseCommand(NSString *json) {
	NSURLComponents* components = [[NSURLComponents alloc] initWithString:json];
	NSArray *queryItems = components.queryItems;
	NSMutableDictionary *command = [[NSMutableDictionary alloc] init];
	for (NSURLQueryItem *item in queryItems) {
		if ([item.name isEqualToString:@"id"]) {
			command[@"id"] = item.value;
		}

		if ([item.name isEqualToString:@"command"]) {
			command[@"command"] = item.value;
		}

		if ([item.name isEqualToString:@"params"]) {
			command[@"params"] = [item.value componentsSeparatedByString:@","];
		}
	}
	return [command copy];
}

// -- K2geLocker --
BOOL hasBiometricsPerm(){
	NSMutableDictionary *infoPlistDict = [NSMutableDictionary dictionaryWithDictionary:[[NSBundle mainBundle] infoDictionary]];
	return [infoPlistDict objectForKey:@"NSFaceIDUsageDescription"] != nil ? true : false;
}

void handleAuthenticate(NSString *uuid) {
	LAContext *context = [[LAContext alloc] init];
	if (hasBiometricsPerm()) {
		[context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:@"K2geLocker" reply:^(BOOL success, NSError * _Nullable error) {
		     if (success){             // on authentication success
				 sendResponse(createResponse(uuid, @"success"));
			 } else {
				 // NSString* errorStr = [NSString stringWithFormat:@"%@", error];
				 // sendResponse(createResponse(uuid, errorStr));
				 sendResponse(createResponse(uuid, @"fail"));
			 }
		 }];
	} else {
		sendResponse(createResponse(uuid, @"fail"));
	}
}

// Handle the command
void handleCommand(NSDictionary *command) {
	NSString *name = [command objectForKey:@"command"];
	if (name == nil) {
		return;
	}
	NSString *uuid = [command objectForKey:@"id"];
	NSArray *params = [command objectForKey:@"params"];
	// -- K2geLocker --
	if ([name isEqualToString:@"K2geLocker"]) {
		if ([params[0] isEqualToString:@"check"]){ // check installed and has perms
			sendResponse(createResponse(uuid, hasBiometricsPerm() ? @"yes" : @"no"));
		} else if ([params[0] isEqualToString:@"authentication"]){ // do authentication
			handleAuthenticate(uuid);
		}
	}
}

%hook GULAppDelegateSwizzler // handle it before Enmity hooks it
- (BOOL)application: (UIApplication *)app openURL: (NSURL *)url options: (NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
	// NSLog(@"K2genmity | openURL: %@", url.absoluteString);
	NSString *input = url.absoluteString;
	if (!validateCommand(input)) {
		%orig;
		return true;
	}

	NSString *json = cleanCommand(input);
	NSDictionary *command = parseCommand(json);
	handleCommand(command);
	return %orig(app, url, options); // pass to Enmity
}
%end


// -- highlightCode --
%hook YYLabel
- (void)setAttributedText: (NSAttributedString *)attributedText {
	/* filter code block by content */
	if ([[attributedText string] hasSuffix:@"-- By CodeHighlight"]){
		CGFloat fontSize = 10;
		BOOL changeFont = false;

		NSMutableDictionary* pref = getPref(@"HighlightCode");
		if (pref){
			changeFont = (BOOL)[pref objectForKey:@"change_font"];
			NSNumber* num = [pref objectForKey:@"font_size"];
			fontSize = [num doubleValue];
		}

		/* create editable NSMutableAttributeString with the original attributedText */
		NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedText];
		__block NSString* fontName = [[self font] fontName];

		if (changeFont){
			fontName = @"Courier";
		}
		/* change the font */
		[attributedString addAttribute: NSFontAttributeName value:[UIFont fontWithName:fontName size:fontSize] range: NSMakeRange(0, [attributedText length])];
		%orig(attributedString);
	} else {
		%orig;
	}
}
%end
