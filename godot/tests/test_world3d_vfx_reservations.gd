extends SceneTree
func _initialize():
 var budget=load("res://scripts/world3d/vfx_reservations.gd").new()
 budget.soft_limit=30
 var normal:Array=[10,10];var minimum:Array=[1,2]
 assert(budget.acquire(1,normal,minimum)==[10,10])
 assert(budget.acquire(2,normal,minimum)==[1,9])
 assert(budget.reserved==30)
 assert(budget.acquire(3,normal,minimum)==minimum)
 assert(budget.reserved==33,"Protected minima may exceed the soft budget")
 budget.release(1);budget.release(1)
 assert(budget.reserved==13,"Release must be idempotent")
 budget.clear()
 assert(budget.reserved==0 and budget.entries.is_empty())
 assert(budget.acquire(1,normal,minimum)==normal)
 assert(normal==[10,10],"Profiles must remain immutable")
 budget.clear();budget.soft_limit=6
 assert(budget.acquire(4,[3,6,4],[3,0,1],[1,2,0])==[3,0,3],"Decorative trail must be reduced before the protected core")
 print("WORLD3D_VFX_RESERVATIONS_PASS")
 quit()
