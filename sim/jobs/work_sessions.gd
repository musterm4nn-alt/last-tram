class_name WorkSessions
extends RefCounted
## Which WorkSession runs a job's shifts (D10): a registry by JobDef.session. On-site work
## uses the rabbit hole until OnSiteWork exists (T-0065). Static, no state.

static var _rabbit_hole: RabbitHoleWork = RabbitHoleWork.new()


static func for_job(_job: JobDef) -> WorkSession:
	return _rabbit_hole
