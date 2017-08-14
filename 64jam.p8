pico-8 cartridge // http://www.pico-8.com
version 10
__lua__
player = {
}

debug_mode = false

ent_explosion = "explosion"
ent_tank = "tank"
ent_debug = "debug"

rocket_tank_chance = 0.3

-- ti - tile index
ti_arrow = 77
ti_tank = 73
ti_boat = 121
ti_turret = 105
ti_boat_turret = 89
ti_rocket_turret = ti_arrow --todo
ti_rocket = 113
ti_explosion = 116
ti_fire = 118
ti_smoke = 101
ti_bullet = 112
ti_flag = 127
ti_rotor_top = 64  
ti_rotor_side = 68
ti_fuel = 24
ti_ammo = 25
ti_refuel = 34
ti_dirt = 9
ti_health = 126

flag_dirt = 1
flag_water = 4

default_item_spawn_chance = 20  -- 20% chance to spawn item on death

-- clockface directions
dirs = {12, 1, 3, 5, 6, 7, 9, 10,}
no_dir = 0

-- ent - entity - anything with a positionreemies, mostly
ents = {}
pickups= {}
projectiles = {}

started = false



-----------------------------------  spawning, instantiating, initializing calls -------------------------------------------------------

function _init()
	poke(0x5f2c,3) -- set screen res to 64x64, per the competition rules
	cls()
	init_vars()
	init_player()
	init_ents()
	init_map()
end


function init_ents()
	test_direction_draw_code(ti_turret, 0)
	test_direction_draw_code(ti_rocket, 1)
	test_direction_draw_code(ti_tank, 3)
	test_tank(ti_tank, 8)
	printh("init_ents")

end


function init_vars()
	ents = {}
	pickups= {}
	projectiles = {}
end


function init_player()
	player = {
		x=84* 8 - 4, 
		y=40.5* 8 - 4, 
		dir=5,
		bullets = 2000,
		rockets = 16,
		fuel = 800, 
		health = 2000,
		hostile = true,
		bulletdamage = 55,
		rocketdamage = 400,
		bullet_heat = 0,
		rocket_heat = 0,
		heat = 0,
	}
end

function is_foo(i, j, flagi)
	local ti =  mget(i, j)
	local isdirt = fget(ti, flagi)
	return isdirt
end

function is_dirt(i, j)
	return is_foo(i, j, flag_dirt)
end

function is_water(i, j)
	return is_foo(i, j, flag_water)
end

function spawn_random_tank(x, y, r)
	local i = x / 8 
	local j = y / 8

	local ri = rnd(2*r) - r -- a range of  -r to r tiles
	local rj = rnd(2*r) - r 

	i += ri
	j += rj 
	p = {}
	p.x = i * 8
	p.y = j * 8
	local spawn_fn = false

	if is_dirt(i,j) then
		spawn_fn = spawn_tank
	elseif is_water(i,j) then
		spawn_fn = spawn_boat
	else
		return false
	end

	if is_nearby_ent(p) then
		return false
	end

	local tank = spawn_fn(i * 8, j * 8)
	local rand = rnd(1)
	if (rand < rocket_tank_chance) then
		set_rocket_stats(tank)
	end
	return true
end

function is_nearby_ent(point) 
	for e in all(ents) do
		if dist8(e, p) <= 3 then return true end
	end
	return false
end

-- r - radius
function spawn_random_tanks(x, y, r, n)
	local count = 0
	for i = 1, n*2 do
		if spawn_random_tank(x, y, r) then
			count += 1
		end
		if count >= n then
			return
		end
	end
end

function spawn_item(typ, ti, x, y)
	local item = spawn_ent(ent_ammo, x, y, no_dir)
	item.ti = ti
	item.item = true
	item.bullets = 0
	item.rockets = 0
	item.health = 0
	item.fuel = 0
	return item
end


function spawn_random_item(x, y)
	local fns = {spawn_ammo, spawn_fuel, spawn_health}
	local i = flr(rnd(3)) + 1
	fns[i](x, y)
end

function spawn_ammo(x, y)
	local item = spawn_item(ent_ammo, ti_ammo, x, y)
	item.bullets = 1000
	item.rockets = 8
	return item
end
function spawn_fuel(x, y)
	local item = spawn_item(ent_ammo, ti_fuel, x, y)
	item.fuel = 400
	return item
end
function spawn_health(x, y)
	local item = spawn_item(ent_ammo, ti_health, x, y)
	item.health = 1000
	return item
end

function spawn_boat(x, y)
	local tank = spawn_ent(ent_boat, x, y, 3)
	tank.ti = ti_boat
	tank.turret_ti = ti_boat_turret
	set_basic_stats(tank)
	return tank
end

function spawn_tank(x, y)
	local tank = spawn_ent(ent_tank, x, y, 3)
	tank.ti = ti_tank
	tank.turret_ti = ti_turret
	set_basic_stats(tank)
	return tank
end

-- sets the basic stats for a tank or boat
function set_basic_stats(tank)
	tank.turret_dir = 12
	tank.health = 400
	tank.agro_range8 = 4  -- aggrevation range, how close before they try to attack you.  the two is because it's the square of the distance
	tank.hostile = true
	tank.bullets = 5000
	tank.bulletdamage = 15
	tank.bullet_heat = 2  -- amount of heat firing a bullet costs
	tank.rocketdamage = false
	tank.rockets = 0
	tank.item_spawn_chance = default_item_spawn_chance
	tank.heat = 0 -- how hot the tank is (how long it has to wait before firing again)
end

-- upgrade a tank to rocket tank
function set_rocket_stats(tank)
	tank.rocketdamage = 400
	tank.rockets = 10 --nb, they will start firing bullets when they run out of rockets
	tank.turret_ti = ti_rocket_turret
	tank.rocket_heat = 20
end


function debug_status(msg, ent)
	printh("--------------")
	printh(msg)
	printh(trace())
	printh("ent count: " .. #ents)
	printh("projectile count: " .. #projectiles)
	if ent then
		debug_ent(ent)
	end
	printh("")
	printh("player:")
	debug_ent(player)
end

function debug_ent(ent)
	printh("ent - typ:" .. (ent.typ or "nil") .. " " .. ent.x .. "," .. ent.y)
end

function spawn_explosion(x,y, item_spawn_chance)
	--debug_status("spawn explosion " .. x .. "," .. y)
	if pget(x+4,y + 4) != 12 then	 -- this does a pixel color check at the explosion location to make sure the color isn't blue (water)
		sfx(3)
		local exp = spawn_ent(ent_exp, x , y, 12)       
		exp.item_spawn_chance = item_spawn_chance or 0
		exp.ti = ti_explosion
		exp.offset = 0
		exp.t = 0 --timer
		exp.framecount = 3
		exp.drawnthframe = 4 --update animation every nth frame
	end
end


-- create an entity
function spawn_ent(typ, x, y, dir)
	local ent = {
		x = x,
		y = y,
		dir = dir,
		typ = typ,
		item_spawn_chance = 0,
		hostile = false, --default
		health = 400,
		rad = 10
	}
	add(ents, ent)
	return ent
end

function init_map()
	for i = 1, 128 do 
		for j = 1, 64 do
		--loop through map and exchange tiles for entities
			local ti = mget(i,j)
			local x = i * 8
			local y = j * 8
			if ti == ti_flag then
				local tank = spawn_tank(x,y)
				mset(i, j, ti_dirt)
				--printh('spawned tank in init_map')
				spawn_random_tanks(x,y,  6, rnd(2) + 2)
			end
			if ti == ti_ammo then
				local ammo = spawn_ammo(x,y)
				mset(i, j, ti_dirt)
			end
			if ti == ti_health then
				local ammo = spawn_health(x,y)
				mset(i, j, ti_dirt)
			end
			if ti == ti_fuel then
				local ammo = spawn_fuel(x,y)
				mset(i, j, ti_dirt)
			end
		end
	end
end
-----------------------------------  test helpers -------------------------------------------------------

function log(msg, offset)
	print (msg, player.x - 31, player.y - 31 + offset * 8, 7)
end

function test_direction_draw_code(ti, dy)
	for i,dir in pairs(dirs) do
		local tank = spawn_ent(ent_debug, player.x + 8*4 + i * (8), player.y + dy*8)
		tank.dir = dir
		tank.turret_ti = false
		tank.ti = ti
	end
end

function test_tank(ti, dy)
	for i,dir in pairs(dirs) do
		local tank = spawn_tank(player.x + 8*4 + i * (8), player.y + dy*8)
		tank.dir = dir
	end
end



-- distance in tiles between two ents/projectiles
function dist8(a, b)
	local scale = 8  -- sacrifice accuracy to avoid overflowing, return distance in tiles
	return sqrt((a.x/scale - b.x/scale)^2 + (a.y/scale - b.y/scale)^2)
end

function go_agro(e) 
	--debug_status("agro", e)
	if (rnd(1) < .3 and e.heat == 0) then
		if (e.rockets > 0) then
			fire_rocket(e)
		else
			fire_bullet(e, rnd(2)+2)
		end
	end
end
function check_agro() 
	for e in all(ents) do
		if (e.hostile) then
			local dist = dist8(e, player)
			if (e.agro_range8 > dist) then
				-- printh("dist8 - " .. dist)
				go_agro(e)
				if debug_mode then e.turret_ti = ti_arrow end
			else
				if debug_mode then e.turret_ti = ti_turret end
			end
			aim_turret(e, player)
		end
	end
end

function aim_turret(ent, target)
	-- todo - in progress
	local dx, dy = round_deltas(ent_deltas(ent, target))
--	log(dx, 0)
--	log(dy, 1)
	local dir = deltas_to_dir(dx, dy)
--	log(dir, 2)
	ent.turret_dir = dir
end


function set_player_dir_from_buttons()
	local newdir = 0
	if btn (1) and btn (2) then
		newdir = 1
	elseif btn (1) and btn (3) then
		newdir = 5
	elseif btn (0) and btn (2) then
		newdir = 10
	elseif btn (0) and btn (3) then
		newdir = 7
	else
		if btn(0) then 
			newdir = 9
		end
		if btn(1) then 
			newdir = 3 
		end
		if btn(2) then 
			newdir = 12
		end
		if btn(3) then 
			newdir = 6
		end
	end

	if newdir == 0 then  
		player.moving = false
	else
		player.dir = newdir
		player.moving = true
	end
end

function update_player()
	if started then player.fuel -= 1 end
	if player.moving then
		local dx
		local dy 
		local speed = 1
		dx, dy = dir_to_deltas(player.dir, speed)
		player.x += dx
		player.y += dy
	end
	player_collision_check()
end

-----------------------------------  update calls -------------------------------------------------------

function respawn()
	init_player()
end

function _update()
	if started == true then
		sfx (1)	
	end

 if player.health <= 0 then respawn() end

	if btn(0) or btn(1) or btn(2)
		or btn(3) or btn (4) or btn(5) then
		started = true
	end

	set_player_dir_from_buttons()

	update_player()
	update_ents()
	update_projectiles()
	
	if btn(5) then fire_bullet(player) end
	if btnp(4) then fire_rocket(player) end
end


-- returns true iff the projectile runs out of fuel
function update_projectile(b)
		b.x += b.dx
		b.y += b.dy
		b.fuel -= 1

		if b.fuel < 0 then
			del(projectiles, b)
			if b.explode_when_out_of_fuel then
				spawn_explosion(b.x, b.y)
			end
			return true
		end
		return false
end

function handle_destruction(ent)
end

function update_ent(ent)
	if (ent.heat and ent.heat > 0) then
		ent.heat -= 1
	end
end

function update_ents()
	for r in all(ents) do
		update_ent(r)
	end
end

function update_projectiles()
	for r in all(projectiles) do
		update_projectile(r)
		collision_check(r)
	end
end


-----------------------------------  helpers -------------------------------------------------------


-- called when a ent (currently only ever the player) runs over another 'item' (since it is ideally an item)
function ent_collide(ent, item)
	if not item.item then return end
	del(ents, item)
	-- todo: play sound
	ent.health += item.health
	ent.rockets += item.rockets
	ent.bullets += item.bullets
end


-- check the player running into ents
function player_collision_check(r)
	for e in all(ents) do
		if one_collision_check(player, e, ent_collide) then
			return
		end
	end
end

-- check projectiles running into ents
function collision_check(r)
	for e in all(ents) do
		if one_collision_check(r, e, collide) then
			return
		end
	end
	one_collision_check(r, player, collide)
end

function one_collision_check(r, e, collide_fn)
	if (r.owner != e) then
		if dist8(r, e) < 1 then
			collide_fn(r, e)
			return true -- nb, can only hit one thing
		end
	end
	return false
end

function collide(r, e) --check bullets against things
	e.health -= r.damage
	if (e.hostile == true) then
		del(projectiles, r)
	end
	if (e.health <= 0) then
		del(ents, e)	
		spawn_explosion(e.x, e.y, e.item_spawn_chance)		
		handle_destruction(ent)
	end
end


-- converts a direction and speed to a dx, dy
function dir_to_deltas(dir, speed)
	local dx = 0
	local dy = 0

	if dir == 12 or dir == 10 or dir == 1 then
		dy = -speed
	end
	
	if dir == 5 or dir == 6 or dir == 7 then
		dy = speed
	end
	 
	if dir >= 1 and dir < 6 then
		dx = speed
	end
	if dir > 6 and dir <= 10 then
		dx = -speed
	end 
	return dx, dy
end



function round_deltas(dx, dy)
	if abs(dx) > abs(dy) * 2 then
		dy = 0
	elseif abs(dy) > abs(dx) * 2 then
		dx = 0
	end
	return dx, dy
end

		

-- todo - in progress
function ent_deltas(a, b)
	return b.x - a.x, b.y - a.y
end

-- todo - in progress
function deltas_to_dir(dx, dy)
	local dir = 0


	if (dy < 0) then
		if (dx < 0) then
			dir = 10
		elseif (dx == 0) then
			dir = 12
		else 
			dir = 1
		end
	elseif (dy == 0) then
		if (dx < 0) then
			dir = 9
		elseif (dx == 0) then
			dir = 0
		else 
			dir = 3
		end
	else -- dy > 0
		if (dx < 0) then
			dir = 7
		elseif (dx == 0) then
			dir = 6
		else 
			dir = 5
		end
	end
	return dir
end

function ent_get_aim_dir(ent)
	if ent.turret_dir then
		return ent.turret_dir
	end
	return ent.dir
end


function create_projectile(owner_ent, speed)
		local dx
		local dy

		local dir = ent_get_aim_dir(owner_ent)
		
		dx, dy = dir_to_deltas(dir, speed)

		local r = {
			owner = owner_ent,
			x = owner_ent.x,
			y = owner_ent.y,
			dir = dir,
			dx = dx,
			dy = dy
		}
		return r
end

function fire_rocket(owner_ent, speed)
	if (owner_ent.rockets > 0) then
		sfx(2)

		speed = speed or 6
		local r = create_projectile(owner_ent, speed)
		r.fuel = 7
		r.damage = owner_ent.rocketdamage
		r.rad = 20
		owner_ent.heat += owner_ent.rocket_heat

		r.ti = ti_rocket
		r.explode_when_out_of_fuel = true
		add(projectiles, r)
		owner_ent.rockets -= 1
	end
end

function fire_bullet(owner_ent, speed)
	if (owner_ent.bullets > 0) then
		sfx (0)

		speed = speed or 4
		local b = create_projectile(owner_ent, speed)
		owner_ent.heat += owner_ent.bullet_heat
		b.fuel = 10
		b.damage = owner_ent.bulletdamage
		b.ti = ti_bullet
		b.dir = 1

		add(projectiles, b)
		if (owner_ent.bullets) then
			owner_ent.bullets -=1
		end
	end
end

-----------------------------------  draw calls -------------------------------------------------------

-- ent - entity, anything with a position and a sprite
function draw_ent(e)
	spr_ent(e)
end

function draw_ents()
	for e in all(ents) do
		draw_ent(e)
	end
end

-- draw a sprite facing a direction
function spr_with_dir(ti, x, y, dir)
	local diag_offset = 0
	local up_offset = 1
	local right_offset = 2

	-- no dir, use no offset
	if (dir == no_dir) then spr(ti,x,y,1,1,false,false)  end

	if (dir == 12) then spr(ti+up_offset,x,y,1,1,false,false) end
	if (dir == 1) then spr(ti+diag_offset,x,y,1,1,true,false)  end
	if (dir == 3) then spr(ti+right_offset,x, y) end
	if (dir == 5) then spr(ti+diag_offset,x, y, 1, 1, true, true) end
	if (dir == 6) then spr(ti+up_offset,x, y, 1, 1, false, true) end
	if (dir == 7) then spr(ti+diag_offset,x,y,1,1,false,true) end
	if (dir == 9) then spr(ti+right_offset,x,y,1,1,true,true) end
	if (dir == 10) then spr(ti+diag_offset,x,y,1,1,false,false) end
end

function handle_explosion_end(ent)
	if (rnd(100) < ent.item_spawn_chance) then
		-- sometimes, spawn an item
		spawn_random_item(ent.x, ent.y)
		del(ents, ent)
		return
	else
		-- turn into fire
		ent.framecount = 2
		ent.drawnthframe = 3
		ent.ti = ti_fire 
	end
end
		
function draw_animated(ent)
		spr_with_dir(ent.ti + ent.offset, ent.x, ent.y, ent.dir)	
		drawn = true
		ent.t += 1
		if ent.t >= 160 then 
			del(ents, ent)
		end
		
		if(ent.t % ent.drawnthframe == 0) then
			ent.offset += 1
			if ent.offset == ent.framecount then 
				ent.offset = 0
				if (ent.ti == ti_explosion) then
					handle_explosion_end(ent)
				end
			end  	
		end
end

-- draw a sprite using ent data
function spr_ent(ent)
	if ent.ti == ti_explosion or ent.ti == ti_fire then
		draw_animated(ent)
		return	
	end

	spr_with_dir(ent.ti, ent.x, ent.y, ent.dir)
	if ent.turret_ti then
		spr_with_dir(ent.turret_ti, ent.x, ent.y, ent.turret_dir)
		drawn = true
	end
end



function draw_projectiles()
	for r in all(projectiles) do
		spr_ent(r)
	end
end

function _draw()
	cls()
	sspr(80,0,8,8, player.x-50, player.y-50, 120, 120)
	mapdraw(0,0,0,0,128,64)
	camera(player.x-32, player.y-32)

	log("+" .. player.health .. " r" ..player.rockets .. " b" .. player.bullets, 0)
	--log(test_tank.ti, 1)

	check_agro() --todo: should probably be decoupled from draw

	draw_ents()
	draw_projectiles()
	draw_copter(player.x,player.y)
	
	if (player.bullets <= 40 and player.bullets > 0) then
		print ("low ammo", player.x - 31, player.y - 31, 7)
	end
	
	if (player.bullets <= 0) then
		print ("out of rounds", player.x - 31, player.y - 31, 9)
	end

	if (player.fuel <= 0) then
		print ("low fuel", player.x - 31, player.y - 25, 8)
	end

	if not started then
		print ("���� fly", player.x -30, player.y - 30, 7)
		print ("� machine gun", player.x -30, player.y - 22, 7)
		print ("� rockets", player.x -30, player.y - 14, 7)
	--	print ("micro strike", player.x -30, player.y + 20, 8)

	end
	
	if (player.x <= -30 or player.x >= 1040 or player.y <= -30 or player.y >= 540) then
		print ( "   return to", player.x -30, player.y + 10, 7)
		print ("  mission area", player.x -30, player.y + 20, 7)

	end

end

rotor_offset = 0

function draw_copter(x,y)

	if player.dir == 12 then 
		spr(98, x, y)
	end
	if player.dir == 1 then 
		spr(97, x, y)
	end
	if player.dir == 3 then 
		spr(99, x, y)
	end
	if player.dir == 5 then 
		spr(96, x, y)
	end
	if player.dir == 6 then 
		spr(100, x, y)
	end
	
	if player.dir == 9 then 
		spr(99,x,y,1,1,true,false)
	end
	if player.dir == 7 then 
		spr(96,x,y,1,1,true,false)
	end
	if player.dir == 10 then 
		spr(97,x,y,1,1,true,false)
	end
	
	-- rotor drawing code

	local ti_rotor

	-- pick a base rotor tile based on player direction
	if player.dir == 3 or player.dir == 9 then
		ti_rotor = ti_rotor_side
	else
		ti_rotor = ti_rotor_top
	end

	spr(ti_rotor + rotor_offset, x, y) --draw rotor

	if started then
		-- rotate the rotor
		if rotor_offset == 3 then 
			rotor_offset = 0 
		else 
			rotor_offset += 1 
		end 
	end
end
__gfx__
00000000fffffffffffffffffffff6f6ffffffffffffffff0000000000000000ffffffffffffffffccccccccff66665ffffffffdfffffffd666dfffffffbfbff
000000006f6f6f6fffffffffffff6f6fffffdf6f6f6dffff0000000000000000ffff4fffffffffffccccccccf666655fffffffd6ffffffd666dfffffffbbbbbf
00700700f6f6f6f6fffffffffff6f6fffff6d6f6f6fdffff0000000000000000ffffffffffffffffccccccccddddd51ffffffd66fffffd666dfffffffffbbbff
000770006f6f6f6fffffffffff6f6fffff6fdf6f6f6dffff0000000000000000ffffffffffffffffccccccccddddd15ff7878786ffffd666dfffffffffbf5fbf
00077000fffffffffffffffff6f6fffff6f6fffff6f6ffff0000000000000000ffffffffffffffffccccccccd1d1d55ff4fd666dfffd666dfffffffffff44fff
00700700ffffffffffffffff6f6fffff6f6fffff6f6fffff0000000000000000ffffff4fffffffffccccccccddddd5ffffd666dfffd666dffffffffffff5ffff
00000000fffffff6fffffff6f6fffffff6fffffff6ffffff0000000000000000ffffffffffffffffccccccccd1dddffffd666dfffd666dfffffffffffff4ffff
00000000ffffff6fffffff6f6fffffff6fffffff6fffffff0000000000000000ffffffffffffffffccccccccffffffffd666dfffd666dfffffffffffffffffff
0000000000000000fffff6f6fffffffffffff6f6f66666ffffffffff666dcccc000000000000000066666666ddddfffffffffffd666dddddddddddddffffffff
0000000000000000ffffdf6f6f6f6f6f6f6fdf6f6ff6ff6fffff3fff66dccccc0099999000ddddd06666666666dfffffffffffd66666666666666666ffffffff
0000000000000000ffffd6f6f6f6f6f6f6f6d6fffff6fffffff333ff6ddccccc0097779000dd7dd0666666666dfffffffffffd666666666666666666ffffffff
0000000000000000ffffdf6f6f6f6f6f6f6fdffffff6ffffffb3333fdcdccccc0097999000d7d7d066666666dfffffffffffddddddddddddddddddddffffffff
0000000000000000fffffffffffffffffffffffffff6fffffbbb33ffcccccccc0097799000d777d066666666ffffffffffffffffffffffffffffffffff66dfff
0000000000000000fffffffffffffffffffffffffff6fffffb5b3fffcccccccc0097999000d7d7d066666666ffffffffffffffffffffffffffffffffff556fff
0000000000000000fffffffffffffffffffffffffff6ffffffffffffcccccccc0099999000ddddd066666666ffffffffffffffffffffffffffffffffffffffff
0000000000000000fffffffffffffffffffffffffff6ffffffffffffcccccccc000000000000000066666666ffffffffffffffffffffffffffffffffffffffff
cccccccccccc77777777777777777776666666666666555cffffffffcccccccdddddddddffffffff666dfffdccccccccddddddddfffffffccccccccfcccccccc
cccccccccc66666666aaa6666666665666666666666555ccf86fffffccccccd666666666fffd666d66dfffd6cccccccc66666666ffffffccccccccffcccccccc
ccccccccc666666666666666666665566666666666555cccff6ffdddcccccd6666666666ffd666d56dfffd66cccccccc66666666fffffccccccccfffcccccccc
cccccccc666666666666666666665556666666666555ccccff6f6665ccccd666ddddd666fd666d15dfffddddccccccccddddddddffffccccccccffffccccffff
ccccccca66666666676666666665555666666666555cccccffdf6165cccd666dfffd666dd666d115ffffffffcccccccccdcdcdcdfffccccccccfffffcccfffff
cccccca666666666766666666a5555566666666555ccccccffdf616fccd666dcffd666df5ddd5fffffffffffccccccccccdcccdcffccccccccffffffccfffffc
ccccca666666666766666666a5555566666666555cccccccffffffffcd666ddcfd666dff56dd5fffffffffffcdccccccccccccccfccccccccfffffffcfffffcc
cccc6666666666766666666a5555566666666555ccccccccffffffffd666dcdcd666dfff566d5fffffffffffdcdcccccccccccccccccccccfffffffffffffccc
ccc6666666666666666666655555666655556d66ccccccc66666666600000000ddddd666fffffffffff4fff4ddddddddddddddddffffffffcccccccc00000000
cc66666666666666666666555556666655566666cccccc66667777560000000066666666fffbf3fbff4fff4f6666666666666666cffffffffccccccc00000000
c666666666aaa6666666655555666666556666d6ccccc666677775560000000066666666ff35bf35f4fff4ff6666666666666666ccffffffffcccccc00000000
ddddddddddddddddddddd55556666666566f6666cccc6666ddddd55600000000dddd6666fbf3f34544444fffddddddddddddddddcccffffffffccccc00000000
ddddddddddddddddddddd5556666666666666666ccc66666ddddd55600000000fffd666d3f35b4f5fff4fffffffccccccccfffffccccffffffffcccc00000000
ddddddddddddddddddddd5566666666666664665cc666666ddddd55600000000ffd666df54f45fffff4fffffffccccccccffffffcccccffffffffccc00000000
ddddddddddddddddddddd5666666666666666655c6666666ddddd56600000000fd666dff5f4f5ffff4fffffffccccccccfffffffccccccffffffffcc00000000
ddddddddddddddddddddd666666666666f66655566666666ddddd66600000000d666dfff5fff5fff4fffffffccccccccffffffffcccccccffffffffc00000000
000000d000100000000d1000000000d0d70000d00d1700d0170d1006000000000000000000330000000000000000000000000000888800000008800000000000
d70000700d0700d000007000d700007000000000000000000000700000000000000000000333b000003533000000000000000000888000000088880000000800
0000000000000001000000000000000000000000000000000000000000000000000000003335330003333b300333333000494900888800000808808000000080
00000000000000701700000d00000000000000000000000000000000000000000000000035333b300b333330b333333b04dddd90808880000008800000088888
0000000007000000d00000710000000000000000000000000000000000000000000000006333335b033333303533333509494940000880000008800000088888
000000001000000000000000000000000000000000000000000000000000000000000000063533330b3333b0333333b304949490000000000000000000000080
0700007d0d0070d0000700000700007d00000000000000000000000000000000000000000063b330035333303333333309494940000000000000000000000800
0d000000000001000001d0000d000000000000000000000000000000000000000000000000063300003353005656565600000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000b0000000000b00000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000b000000000b00000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000bb500000bb500003bb500000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000b5b00000b5b00005b5bbbb00000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000003bb300003bb000033bb00000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000053500005b30000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b000000000003b3b000000000000000000333b006000600006000000606000000000000060000000000600000000000000000000000000000000000000000000
300000000005b3c30003b000300050000003000006000000000d0000000060000000000006000000000600000000000000000000000000000000000000000000
b3b050000006333b003533003003bc700003b00000d000d060606000d0d000000000000000665000006650000d66500000000000000000000000000000000000
0033b00000bbbb363b33b33b63bbb3cb003c7b00060600000d00000006000d000000000000656000006560000565666600000000000000000000000000000000
00b377b030033b65505335053005656353377335006060000060600060d060000000000000d66d0000d660000dd6600000000000000000000000000000000000
0003c77b303b00500003b00000065650503b3305000000000000000000000000000000000005d5000056d0000000000000000000000000000000000000000000
05653cb3b330000000b33b00000000000003b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0056b33b0b0000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000900880090006000000000000000000005dd000000005d00000000000000000000000000000000000ffffffff
000000000000000000000000000000000000000000898800060996000000000000000000556d500000556d0000000000000000000000000000bbbbb0ffffffff
00000000000008000000000000000000000000000789987000869800000000000000000056d6650000d6650000000000000000000000000000b8b8b0fff5888f
00000000000000700800080000a7800000099000799799970969996000808000000808000d6666500066d6000d656650000000000000000000b8b8b0fff5888f
000a00000000000a0700070000000000079aa970079aa9700796a970008998000089980000566d6000566d00d6d66d6d000000000000000000b888b0fff5ffff
00000000080000000a000a00000a7800007aa7000077a700007aa600008aa800008aa8000005666500d56d0005665650000000000000000000b8b8b0fff5ffff
00000000007000000000000000000000000000000000000000000000000000000000000000005d55006d650000d56d00000000000000000000bbbbb0fff5ffff
00000000000a00000000000000000000000000000000000000000000000000000000000000000d5d0006500000000000000000000000000000000000fff5ffff
a09090909090909020309020309090f0f0f0f0f0f0f0f0f090f0f0f0f0f090909090f0f0f0909090f0f09090909090d0e090f0f0909090909090909090909090
90909090909090909090d2a0a0a0a0a0a0a0a0a0a0a0a0a0d390909090909090909090909090909090d2a0a0a0a0a0a0a07271a0d3909090f0f090d2a0a0a0a0
a0d390909090902030902030909090f0f0f0f090f090f0f0f0909090909090909090f0f0f0f090f0f0f090909090d0e090f0f090909090909090909090909090
909090909090909090d2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d39090d2a0a0a0a0a0a0a0a0a0a07271a0a0a0d390f0f0f090f2a0a0a0a0
a0a090909090203090203090f0f0f0f09090f0f09090f0f0f0f090909090909090f0f0f0f0f0f0f0f0f0f09090d0e09090909090909090909090909090909090
909090909090909090a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0e290e3a0a0a0a0e2d0e0e3a0a0a0a0d390f090d2a0a0a0a0a0
a0a090909020309090309090f0a190f0909090f09090f0f0f0f0909090909090909090f0f0f0f0f0f0f09090d0e0909090909090909090909090909090909090
909090909090909090a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0f2a0e2f090909090d0e0f0909090e3a0a0a0a0a0a0f2a0a0a0a0
a0e290909030909090a1a1a1a1a1a1f090f090f09090f0f0f0f0f0f090909090909090f0f0f0f090909090d0e0909090909090f0f0f090909090909090909090
909090909090f09090b2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0e2d2e29090d0e1e1e1d1e1e1e1e182b190e3a0a0a0e2d2a0a0a0a0
a090909090909090a1a1909090a190a1a19090f0f090f0f0f0f0f0f090909090909090f0909090909090d0e090909090909090f0f0f093f0f0f0909090909090
9090909090909090d2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0e2d2a0a0a07271a0a0a0e29090f1d0e0b09090d2e29090e3a0a0a0a0
e290909090909090a190909090a19090a1a19090f0f0f0f0f090f09090909090909090909090909090d0e090909090909090f0f0f0f0f0f0f0f0f09090909090
909093f0f0909090a0a0a0a0a0a0a0a0a0a0a0a0a05363634252a0a0a0a0a0a0a0a0a0a090909090d0e08090d2e2809090c1d1e182b1d2e2908090f0a0a0a0a0
90909090909090a19090909090a190909090a190909090909090f0f0f0f090909090909090909090d0e0909090909090f0f0f093f0f0f0f0f0f0f0f090909090
90f0f0f0f0f09090a0a0a0a0a0a0a0b2a0a0a0a05363634252a0a0b2a0a0a0a0a0a0a0e2909090d0e09090d2a0a0a0a0a0a0a07271a0e29090b09090a0a0a0a0
909090909090a1909090909090a1a1909090a1909090f0909090f09090f0909090909090909090d0e090909090909090f09390f062f0f0f0f0f0f0f0f0f0f090
90f0f090f0f0f090a0a0a0a0a0a0a0a0a0a0021222324252a0a0a0a0a0a0a0a0a0f2e29090f0d0e090909090909090d2e290d0e0b090b090d0b19090a0a0a0a0
9090909090a1a190909090909090a1909090a1909090f0f09090909090909090909090909090d0e090909090909090909090909090f090f0f090909090909090
9090909090909090a0a0a0a0a0a0a0a0a0a00313234352a0a0a0a0a0a0a0a0a0a0e2909090d0e090908090909090d2e290c1d1e1e1e1e1e1d182b190a0a0a0a0
9090909090a19090909090909090a1a19090a1909090909090909090909090909090909090d0e090909090909090909090909090f0f090909090909090909090
909090f090909090a0a0a0a0a0a0a0a0a05363634252a0a0a0a0a0a0a0a0a0a0a0909090d0e09090f790909090d2e2909090909090909090d0e09090a0a0a0a0
9090909090a1909090909090909090a1a1a1a19090909090909090909090909090909090d0e09090909090909090909090d0e1e1e1e1e1e1e1e1e1e1e1e1e182
b190909090f09090a0a0a0a0a0a0a0a05363634252a0a0a0b2a0a0a0a0a0a0a0e29090d0e090909090909090d2e2909090909080909090d0e0908090e3a0a0a0
d390909090a1a190909090909090909090a1a1a1909090909090909090909090909090d0e09090909090909090909090d0e0909090909090909090909090d0e0
909090909090f090a0a0a0a0a0a0a0a013131352a0a0a0a0a0a0a0a0b2a0a0a0a090c1d182b19090909090d2a0a0a0e2f09090909090d0e09090909090a0a0a0
a09090909090a1a1a19090909090909090a19090a190909090909090909090909090c1d182e1e1e1e1e1e1e1e1e1e1e1e0909090909090909090909090d0e090
9090909090909090a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a09090c1d1e1e1e1e182b1f0f0d2a0a0a0a0a0a0a07271a0a0a0a0a0a0a0a0a0
a090909090909090a1a1a1a1a1a1a1a1a1a1909090a190909090909090909090909090d0e09090909090909090909090909090909090909090909090d0e09090
9092909090909090a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d3909090909090d0e080909090909090909090d0e090f09090909090e3a0a0
a090909090909090909090909090a1a1a19090909090a1a190909090909090909090d0e09090909090909090909090909090909090909090909090d0e0909090
90909090b0b0b0d2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a09090908090d0e090909090909090908090d0e09090909090909090d2a0a0
a0d3909090909090909090909090a1a190909090909090a1a19090909090909090d0e09090909090909090909090909090909090909090909090d0e090909090
909090b0c2c290a0a0a0a0a0a0a0a0a0a081909091a0a0a0a0a0a0a0a0a0a0a0a0a0d3909090c1d1e1e182e1e1e1e1e1e1e182e09090909090909090d2a0a0a0
a0a0d3909090909090908190909090909090909090909090a190909090909090d0e09090909090909090909090909090909090909090909090d0e090f7909090
909090b0a0a0f0a0a0a0a0a0a0a0a0a0a09020909090a0a0a0a0a090a0a0a0a0a0a0a0d39090909090d0e0909090909090d0e090909090909090f190a0a0a0a0
a0a0a0a0d39090909090909090909090909090909090909090a19090909090d0e09090909090909090909090909090909090909090909090c1d1e1e1e1e1e1e1
e1e182b1e3a0d3a0a0f7a0a0a0a0a0a0e7e720202090a0a0a0a0a090a0a0a0a0a0a0a0a090809090d0e0909090909090d0e090909090909040311050a0a0b2a0
a0a0a0a0a0a0d390d2d3909090909090909090909090909090a190909090d0e09090909090909090909090909090909090909090909090909090909090909090
90d0e090d2a0a0a0a090a0a0a0a0a0a0e79090909090a0a0a0a0a0f7a0a0a0a0a0a0a0a0d39090d0e0909090909090d0e090f0204031509061203090e3a0a0a0
a0a0a0a0a0a0a0a0a0a0d3909091909090909090909090909090a19090d0e0909090909090909090909090909090909090909090909090909090909090909090
d0e09090a0a0a0a0a090a0a0a0a0a0a0a081909091a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a090c1d1e1e182e1e1e1e1e090902030809090902030809090a0a0a0
a0a0a0a0a0a0a0a0a0a0a0a0d390909090909090909090909090a190d0e0909090909090909090909090909090909090909090909090909090909090909090d0
e0909090a0a0a0a0a090a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a090908090d0e090909090f190902131313131314190909090a0a0a0
a0a0a0a0a0a0a0a0a0a0a0a0a0d3909090909090909090909090a1d0e0909090909090909090909090909090909090909090909090909090909090909090d0e0
90909090a0f2a0a0a0f7a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a090f090d0e090909090909090909090909090909090b090f0a0a0a0
a0a0a0a0a0a0a0a0a0a0a0a0a0a0d3909090909090909090909090a1909090909090909090909090909090909090909090909090909090909090909090c1d1e1
82b19090a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d390d0e09090909090909090d0e1e1e1e1e1e1e1e1e1e1e1b3c2a0
a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d39090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090d0
e0909090f2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0c1d1e1e1e1e1e1e1e1e182e0f090616161616190f190d2a0a0a0
a0a0a0a0a0a0a0a0a0a0a0a0a0c2c2c2c3e19090909090909090909090909090909090909090909090909090909090909090909090909090909090809090d0e0
90909090a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d39090909090f7f090d0e0f0906161616161619090d2a0a0a0a0
a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d3909090909090909090909090909090909090909090909090909090909090909090909090909090909090d0d1e1
e1e182b1a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d390f090d0e0f09090616161616190d2a0a0a0a0a0a0
a0e29090e3a0a0a0a0a0a0a0a0a0a0a0a0a0a0d390909090909090909090909090909090909090909090909090909090909090909090909090909090d0e09090
90d0e0d2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a07271a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0
a090b0f190e3a0a0f2a0a0a0f2a0f2a0a0a0a0a0909090909090909090909090909090d2a0a0a0a0a0a0a0a0a0a0a0a0a0d3909090909090909090d0d1e1e1e1
e1d1e1b3c2c2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a07271a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0
a0f090908090d2a0a0a0a0e290f0d2a0a0a0a0a0d3909090909090909090909090d2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d390909090c1e090909090
90b0d2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0
a0d3d2a0a0d2a0a0a0f2e29080d2a0a0a0a0a0a0a0a0a0d39090909090909090d2a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d3909090909090d2a0a0
a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0
a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0d39090d2a0a0a0a0a0
a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0

__gff__
0000000000000002020210000002020000000000000000000000000200020202000000000000000000000010000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a2e09090909093e0a0a0a0a0a0a0a0a2e09090909090909093e0a2e09093e0a0a0a0a0a0a0a0a0a0a093e0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a2f0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a
0a0a0a0a0a2e09090f0f0f0f0f090f09090f09090f2d0a0a0a0a0a2e090f09090909090909090f0f0f0f0f0f09090f0f0f0909090909093e0a0a0a2e09093e0a2e0909093e0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a2e09092d0a2e0909093e0a0a2f0a0a0a0a0a0a2e09090909090f090909093e0a0a0a
0a0a0a0a2e0f0f0f0f0f0f0f0909090f09090f092d2e0f092d0a2e090909090909090f09090f090f090f090f0f0909090f090909090f09090a0a2e0909090909090f0909093e0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a2e0909090f09093e0909090f090909093e2e090909090909090909090909090f09093e0a0a
0a0a0a0a0f0f0f0f0f0f09090f0909092d0a0a0a2e090909090909090f0f090909090909090f09090f0f0f0f39090f0909090909090909090a0a3d09090909090909090909090f09093e0a0a0a0a0a0a0a0a0a0a0a0a0a0a2e0909090909090909090909090909090909090909090b09090f09090f0909090909090909090a0a
0a0a2f2e0f0f0f0f0f0f09090909090f0909090909090f0f0f0f0f0f0f0f090909090909090909090f0f0f090909090909090909090909093e2f2e09090f090909090909090f0f0909093e0a0a0a0a0a0a0a0a0a0a0a0a2e0909090909090909090204131313131313131301050d281b09090909090909090f09090909093e0a
0a2e09160f0f0f0f0f3902041313131301050f09090f0f090f0f0f0f090909090909090f0909090f090909090909090f0f09090f09090909090909090909090909090909090909090909093e0a0a0a0a0a0a0a0a0a0a2e09090f09090909090f020309290d1b0d1b090902031c1d1d1e1e1e1e1e1e1e1e1e1e1e1e1e281b090a
0a09090f0f0f0f390f020329090909091213010509090f0909090f0f090909090909090f0f0f0f09090909090f090909090909090909090909090909090909090909090909090909090909093e0a0a0a0a0a0a0a2e090909090f0909090909020309290d0e0d0e09090912131313131313131313130105090909090d0e09090a
0a3d080f0f0f0909020329090909090909091213131313130105090f090f09090f0f0f0f0f0f0f0f0f0909090f09090f09090909090909090f0909090909080909090909097f090909090909093e0a0a0a0a0a0a09090909090909090909020309290d0e0d0e090b0909090909090909090909090203090909090d0e09092d0a
0a0a3d0f0909090203290909090909090d1b09090909090912130105090909090f0f09090f0f390909090f090909090909090909090909090f0909090909090909090909090909090909090909090a0a0a0a0a2e090f097f09090f0909020309290d0e0d0e090b09090b0b0b090909090909090203090909090d0e09090f0a0a
0a0a0a3d09090203290909090909090d0e02041301050909090203090909090909090909090f0f09090f0f090f09090909090909090909090909090f0909090909090909090909090909090f0f0f0a0a0a0a0a090909090909090909020309290d0e0d0e090909090d1e1e281b0b090b09261314090909090d0e0f090f393e0a
0a0a0a2e0f0203290909090909090d0e02030802030909090b1213131313131313010509090f0f0f0f0f0909090909090f0f09090909090f0909090909090909090909090f090909090f0f0f0f090a0a0a0a0a0909090909090909020309290d0e0d0e090b09090d0e0b0d1d1e1e1e281e1e1e1e1e1e1e280e0909090909090a
0a0a0a090203290909090909090d0e09121313140909090b0d282828281e281b020309090f0f0f090f090909090909090909090909090909090909090909090909090909090909090909090f09090a0a0a0a0a09090909090909020309290d0e0d0e090b09091c1d1e1e0e0909090d0e0105090909090d0e090909090809093e
0a0a0a0203290909090909090d0e02041301050909090b0d2a1d2a1d0e0d0e02030909090f0f0f0f0f0f09090909090909090909090909090909090909090909090909090909090909090f0f09090a0a0a0a0a09090f090909020309091c0e1c0e0909090909090909090909260c0e0203090909091c1d1e1e1e1e1e281b3909
0a0a0a12131313010509090d0e02030802030909090b0d0e0d1b0d1b0d0e020309090f09090909090f0f0909090f0909090909090909090909090909090909090909090909080909090f0f09092d0a0a0a0a0a090909090909121313131313131313131313131313130105160d0e0203090909090f0909090909260c0e09092d
0a0a0a09090f020309090d0e09121313140909090b0d0e0d0e0d0e0d0e020309090909090909090909090909090909090909090909090909090809090909090909090f090909090909090909090a0a0a0a0a0a3d0909090f090909090909090909090909090909090203160d0e0203090809090d1e1e1e1e1e1e1e0e090f0f0a
0a0a0a090f020309091c1d1e1e1e1e1e1e281b0b0d0e0d0e0d0e0d0e02030909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090f090a0a0a0a0a0a0a090909090809090b0b0b0b0b0b0b080b0909090203160d0e0203090909090d0e0f090909090909090f0f0f0a
0a0a0a090203090909090909090909090d0e0b0d0e0d0e0d0e0d0e0912131313131313130105090909090909090909090809090909090909090909090909090909090909090909090f0f0909090a0a0a0a0a0a0a3d09090909090d1e1e1e1e1e1e1e281b09090203160d0e0203090909090d0e0909097f0909090909090f090a
0a0a0a0912131313131313130105090d0e0b0d0e0d0e0d0e0d0e0b090b090b090b09090203090909090909090909090909090909090909090909090909090909097f090909090f0f0f090909090a0a0a0a0a0a0a0a090909090d0e0f2d2e2d2e0f0d0e09090203160d0e0203090909090d0e0f090909090909090f090909090a
0a0a2e090f09090f090f090203091c1d1e1e1d1e1d1e1d1e1d1e1e1e1e1e1e281b0902030909090909097f09090909090909090909090909090909090909090909090909090f0f09090909090f0a0a0a0a0a0a0a0a0908090d0e0f090909090f0d0e09090203160d0e0203090909090d0e090909090f0909090909090909090a
0a2e090f0f0f0f0f0f0902030909160909091609090909090909090909090d0e0902030909090909090909090909090909090909090909090909090909090909090909090909090909090909090a0a0a0a0a0a0a0a09090d0e0b0b0b0b0b0b0d0e0b090203161c0e0203090909090d0e0f090909090909090909090f0909093e
0a090f0f0f0f0f0f0902030909160909091609090909090909090909090d0e09091213090909090909090909090909090909090909090908090909090d1e1e1e1e1e1e1e281b090909090d1e3b2c2c2c2c2c2c2c2c1e1e1d1e1e1e1e1e1e1e1d281b0f121313131314090909090d0e09090909090909097f09090f0909090909
0a0f0f0f0f0f0f0902030909160909091609090809090909090909091c1d1e1e1e1e1e1e1e1e1e1e1e1e1e1e281b090909090909090909090909090d0e090f0f0f09090d0e0b0b0b260c0e090a0a0a0a0a0a0a0a0a090909090809090909090d0e090909091f0909090909090d0e0f09090909090909090909090f090909092d
0a090f0f0f090f0203090916090909160909090909097f09090909090909090204130909090909080909090d0e090909090909090909090909090d0e090f0f0909091c1d1e1e1e1e1e0e09090a0a0a0a0a0a0a0a0a3d09090909090909091c1d1e1e1e1e1e1e1e1e1e1e1e280e09090909090909090909090909080909090f0a
0a09090f0f090203090916090909160909090909090909090909090909090203090909090909090909260c0e090809090909090909090909090d0e090f09097f0909090909090909090909090a0a0a0a0a0a0a0a0a0a3d090909090909090809090909090809090909090d0e0f090909090909090f0908090909090909092d0a
0a090909090203090916090909160909090909090909090909090909090203090909090909090909091c1d281e1e1e1e1e1e1e1e1e1e1e1e1e0e090909090909090909090909090f0f0909090a0a0a0a0a0a0a0a2e09090909090909090909090909090909090909090d0e0909090909090909090909090909090909092d0a0a
0a3d0f09020309091609090916090909090909090909090909090909020309090f090909080909090f090d0e090909090909090909090909090909090909090909090909090f0f09090909090a0a0a0a0a0a0a2e2d0a2e09090909090909090909090909090909090d0e0f0909090909080909090909090909090909090a0a0a
0a0a0902030909160909091609090909090909090909090909080902030909090909090909090909090d0e09090909090f0f0f0f0f0f0f090909090909090909090f090f090f0909090909090a0a0a0a0a0a0a0a0a2e09090809080909090909090908090909090d0e090909090909090909090909090909090f0909090a0a0a
0a2e09121313131313131313130105090204131313131313131313140909090809090909090909090d0e0909090909090f090f0f09090f0f0f0f09090909090909090909090909090909092d0a0a0a0a0a0a0a0a0a090909090909091f7f0909091f090909090d0e0f09090809090f09090909090909090909090909090a0a0a
0a090f09090909090909090902030902030909090909090909090909090909090909090f0909090d0e09090908090909090909090f09090909090f090909090909090909090909090909090a0a0a0a0a0a0a0a0a0a090809090909090909090909090909090d0e0909090909090909090909090909090b0d1e281b09090a0a0a
0a3d09090909090909090902030902030909090f0f090909090909090f0909090909090909090d0e09090909090909090909090909090909090909090909090909090909090909090f09090a0a0a0a0a0a0a0a0a0a0909090909090909090909090909090d0e0f090f090f090f090f090f090f290d281e0e0d0e0909090a0a0a
0a0a2e0909090909090902030902030909090f0f0f0f0f0f090f0f0f0f0f090909090909091c1d1e1e1e1e1e1e1e1e1e1e281b09090909090909090909090909090909090909090f0f09090a0a0a0a0a0a0a0a0a0a3d090909090909090909090909091c1d1e1e1e1e1e1e1e1e1e1e1e1e1e1e281d1d1e280e090f092d0a0a0a
0a2e090909090909090203090203090909090f090f0f0f0f0f0f0f09090f090909090f090f09090909090909090909090d0e090f0f0f0f09090909097f0909090909090f0f0f0f0f0909090a0a0a0a0a0a0a0a0a0a0a3d0909090909090909090909090909090909090909090909090909090c0e0f091c0e090909090a0a0a0a
__sfx__
00010000140400c050140500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000407002070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00090000146502025012650126500d64006600046001260011600000000e6000d6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001f65029650266500e6502365012650176501e6501a6501a6501965001650156501565012650116500f6500e6500c65009650056500565004650016500364002630016200161002600026000260002600
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

