class_name ProfileEntry
extends Resource
## Membership of an [AntBehavior] inside a [BehaviorProfile]: the behavior
## reference plus the priority and enabled flag this PARTICULAR profile
## assigns it. Priority is membership data, not behavior identity — the
## same behavior resource can sit at priority 100 in the worker profile and
## 30 in the scout profile.
##
## PERSISTENCE: entries are DELIBERATELY embedded subresources of their
## owning profile — membership data, never cataloged, no id. The referenced
## behavior must be a saved external resource (leaves before parents); only
## this wrapper shell embeds.
##
## Enabled here is the PROFILE-level switch (authoring). The per-ant local
## disable mechanism in BehaviorManager remains a separate, subtractive
## runtime override and never mutates this resource.

#region Properties
## The cataloged behavior this entry admits into the profile.
@export var behavior: AntBehavior

## Higher priorities are considered first within the behavior's channel.
@export var priority: int = 0

## Disabled entries are skipped entirely (togglable from UI at runtime).
@export var enabled: bool = true
#endregion
