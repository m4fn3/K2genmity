#import "Tweak.h"

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
		if ([params[0] isEqualToString:@"check"]){         // check installed and has perms
			sendResponse(createResponse(uuid, hasBiometricsPerm() ? @"yes" : @"no"));
		} else if ([params[0] isEqualToString:@"authentication"]){         // do authentication
			handleAuthenticate(uuid);
		}
	}
}

%hook GULAppDelegateSwizzler // handle it before Enmity hooks it
- (BOOL)application: (UIApplication *)app openURL: (NSURL *)url options: (NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
	// NSLog(@"K2genmity | %@", url.absoluteString);
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
/* YYTextContainer: https://github.com/ibireme/YYKit/blob/4e1bd1cfcdb3331244b219cbd37cc9b1ccb62b7a/YYKit/Text/Component/YYTextLayout.m#L280 */
%hook YYTextContainer
- (void)setMaximumNumberOfRows: (NSUInteger)maximumNumberOfRows {
	// NSLog(@"K2genmity | value %ld", (long)maximumNumberOfRows);
	if (maximumNumberOfRows == 3){
		maximumNumberOfRows = 100;
	}
}
%end

//%ctor {
//    NSLog(@"K2genmity | Init!");
//}
