#pragma once

// webrtc M140 (branch-heads/7339) moved a number of symbols out of the rtc:: and
// cricket:: namespaces into webrtc::. These aliases keep the existing call sites
// compiling without a wholesale rename. Include this before any rtc::/cricket:: use.
//
// Only namespace moves are handled here; signature changes are fixed at the call sites.

#include <optional>

#include "api/audio_options.h"
#include "api/make_ref_counted.h"
#include "api/scoped_refptr.h"
#include "api/video/video_sink_interface.h"
#include "api/video/video_source_interface.h"
#include "rtc_base/crypto_random.h"
#include "rtc_base/event.h"
#include "rtc_base/logging.h"
#include "rtc_base/ref_counted_object.h"
#include "rtc_base/thread.h"

namespace rtc {
using webrtc::CreateRandomId;
using webrtc::CreateRandomUuid;
using webrtc::Event;
using webrtc::LoggingSeverity;
using webrtc::LogMessage;
using webrtc::LogSink;
using webrtc::RefCountedObject;
using webrtc::scoped_refptr;
using webrtc::Thread;
using webrtc::VideoSinkInterface;
using webrtc::VideoSinkWants;
using webrtc::VideoSourceInterface;
} // namespace rtc

namespace cricket {
using webrtc::AudioOptions;
} // namespace cricket
