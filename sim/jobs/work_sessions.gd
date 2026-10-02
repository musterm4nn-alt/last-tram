class_name WorkSessions
extends RefCounted
## Which WorkSession runs a job's shifts (D10): a registry by JobDef.session. Static, no state.

static var _rabbit_hole: RabbitHoleWork = RabbitHoleWork.new()  # lint-ok: a stateless session
static var _on_site: OnSiteWork = OnSiteWork.new()  # lint-ok: a stateless session


static func for_job(job: JobDef) -> WorkSession:
	return _on_site if job != null and job.session == JobDef.ON_SITE else _rabbit_hole
