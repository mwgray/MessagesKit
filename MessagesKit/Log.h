//
//  Log.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/20/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@import CocoaLumberjack;


# define MK_LOG_LEVEL_DEFAULT DDLogLevelWarning

# define MK_DECLARE_LOG_LEVEL_AT(level) static const DDLogLevel ddLogLevel = level;

# define MK_DECLARE_LOG_LEVEL_0(...) MK_DECLARE_LOG_LEVEL_AT(MK_LOG_LEVEL_DEFAULT)
# define MK_DECLARE_LOG_LEVEL_1(level) MK_DECLARE_LOG_LEVEL_AT(level)

# define MK_DECLARE_LOG_LEVEL_CHOOSER(x, A, BOUND, ...) BOUND

# define MK_DECLARE_LOG_LEVEL(...) \
MK_DECLARE_LOG_LEVEL_CHOOSER(,##__VA_ARGS__, MK_DECLARE_LOG_LEVEL_1(__VA_ARGS__), MK_DECLARE_LOG_LEVEL_0(__VA_ARGS__))

