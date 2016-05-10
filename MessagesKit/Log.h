//
//  Log.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/20/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@import CocoaLumberjack;


# define CL_LOG_LEVEL_DEFAULT DDLogLevelWarning

# define CL_DECLARE_LOG_LEVEL_AT(level) static const DDLogLevel ddLogLevel = level;

# define CL_DECLARE_LOG_LEVEL_0(...) CL_DECLARE_LOG_LEVEL_AT(CL_LOG_LEVEL_DEFAULT)
# define CL_DECLARE_LOG_LEVEL_1(level) CL_DECLARE_LOG_LEVEL_AT(level)

# define CL_DECLARE_LOG_LEVEL_CHOOSER(x, A, BOUND, ...) BOUND

# define CL_DECLARE_LOG_LEVEL(...) \
CL_DECLARE_LOG_LEVEL_CHOOSER(,##__VA_ARGS__, CL_DECLARE_LOG_LEVEL_1(__VA_ARGS__), CL_DECLARE_LOG_LEVEL_0(__VA_ARGS__))

