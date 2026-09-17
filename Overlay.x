// Hide Twitch 31.1's SwiftUI chat-engagement buttons that remain over the
// video after the normal player controls fade.
//
// Twitch emits a specialized runtime class whose full mangled name includes a
// compiler-generated hash, for example:
//   _TtGC7SwiftUI14_UIHostingViewG...OverlayColumnChatEngagementButtonView_
// The hash and address are not stable, so match only the semantic Swift type
// name observed in FLEX. The view is still a UIView, and setting hidden is
// sufficient without altering constraints or rebuilding the SwiftUI overlay.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import "SettingsKeys.h"

extern NSUserDefaults *tweakDefaults;

// Treat a missing key as enabled so this remains default-on without depending
// on constructor order between Logos source files.
BOOL twab_hideOverlayEngagementButtonsEnabled(void) {
    id configured = [tweakDefaults objectForKey:TWABKeyHideOverlayEngagementButtons];
    return configured ? [configured boolValue] : YES;
}

static BOOL twab_isOverlayEngagementView(UIView *view) {
    if (!view) return NO;
    const char *name = class_getName(object_getClass(view));
    return name && strstr(name, "OverlayColumnChatEngagementButtonView") != NULL;
}

static void twab_hideOverlayEngagementViewIfNeeded(UIView *view) {
    if (twab_isOverlayEngagementView(view) &&
        twab_hideOverlayEngagementButtonsEnabled() && !view.hidden) {
        [view setHidden:YES];
    }
}

static void twab_scanOverlayEngagementViews(UIView *root) {
    if (!root) return;
    twab_hideOverlayEngagementViewIfNeeded(root);
    for (UIView *subview in [root.subviews copy]) {
        twab_scanOverlayEngagementViews(subview);
    }
}

// Called by the settings switch so enabling the option also affects an
// already-visible player. Disabling deliberately does not force views visible;
// Twitch regains control of their visibility as it recreates the overlay.
void twab_hideCurrentOverlayEngagementViews(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *window in [UIApplication.sharedApplication.windows copy]) {
            twab_scanOverlayEngagementViews(window);
        }
    });
}

%hook UIView

- (void)didMoveToWindow {
    %orig;
    twab_hideOverlayEngagementViewIfNeeded(self);
}

- (void)setHidden:(BOOL)hidden {
    if (twab_isOverlayEngagementView(self) &&
        twab_hideOverlayEngagementButtonsEnabled()) {
        hidden = YES;
    }
    %orig(hidden);
}

%end
