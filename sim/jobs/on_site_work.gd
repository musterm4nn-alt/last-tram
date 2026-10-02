class_name OnSiteWork
extends RabbitHoleWork
## On-site work (T-0065, D10): a shift behind a counter. Needs change as in the rabbit hole
## (the job's need_rates, or the gentle profile), but the worker stays visible on the staff
## slot, facing the customers, and the counter sells while they are there (Staffing).


func hidden() -> bool:
	return false
