# Subscriptions And Linked Mode

## Rules

### Rule: Linked child devices suppress local expiry handling
Applies to: family
Intent: Avoid showing child-device expiry UX for a parent-managed subscription.
Rule: In linked mode, Family skips local account-expiry notification scheduling for the child device.
Scope: Family linked-mode expiry UX.
Non-rules: This does not mean the parent subscription is healthy; it only changes child-device UX.
Verification: Check linked-mode account expiry vs standalone Family expiry.

### Rule: Linked child state favors managed continuity over local account status
Applies to: family
Intent: Keep child devices usable and parent-managed.
Rule: A linked child device may still present as linked-active even when the local parent-account status is no longer active, because the child cannot resolve the parent subscription state itself.
Scope: Family linked-mode phase/status handling.
Non-rules: Standalone Family devices should not inherit this behavior.
Verification: Compare linked mode vs standalone mode when the parent account expires.
