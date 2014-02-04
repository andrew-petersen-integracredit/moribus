# Moribus

Moribus is a set of tools for managing complex graphs of ActiveRecord objects
for which there are many inbound foreign keys, attributes and associations with
high rates of change, and business demands for well-tracked change history.

##AggregatedBehavior

AggregatedBehavior implements a pattern in which an object's identity is
modeled apart from its attributes and outbound associations. Its attributes and
outbound associations are modeled on an object called an "info object".

Inbound foreign keys will always point at the same object in memory, and the
object will never be stale, as it has no attributes of its own that are subject
to change. This is useful for objects with many inbound foreign keys and
high-traffic attributes/associations, such as statuses. Without this pattern it
would be difficult to avoid many StaleObjectErrors.

##TrackedBehavior

TrackedBehavior implements history tracking on the stack of objects
representing the identity object's attributes and outbound associations.
It implements support for a notion of the "current" "info object".
