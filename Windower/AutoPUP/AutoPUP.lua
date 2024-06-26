--[[	
VERSIONS
	1.1.0.6: Added Hide/Show commands and, register event for login/load to autohide/show based on job

	1.1.0.5: Added Force targeting. //pup ft "Name of Mob"
	
	1.1.0.4: Added Maintenance automation. Toggle maintenance via //pup maint
			  Added the ability to monitor specific debuffs via the settings.xml
			  Good amount of code cleanup. (hope nothing is broken ^^)
			  
	1.1.0.3: Will no longer attack enemy avatars & pets in Dynamis[D]. You can add additional mobs to the ignore list in the settings xml.
			  Added target fallback logic when <bt> is an invalid target. Will no attempt to assist a party members target.
			  Added Repair Oil setting and new command 'oil <0|1|2|3>' ie: //pup oil 0 <-- will set repairoil setting to 'Automaton Oil'. Default is Automat. Oil +3
			  Adjustments to the textbox layout.
			  
	1.1.0.2: Automatically turns off when you leave a battlefield
	1.1.0.1: New command added, allows setting multiple maneuvers at once, ie: //pup mans fire wind light
	1.1.0.0: Auto deploy and auto activate added. Will now auto equip +3 oils before attempting to repair.
]]

_addon.author = 'Icy (Updated by Sevi)'
_addon.name = 'AutoPUP'
_addon.commands = {'autopup','pup'}
_addon.version = '1.1.0.6'

require('pack')
require('lists')
require('tables')
require('strings')
res_buffs = require('resources').buffs
texts = require('texts')
config = require('config')

debugmode = false

default = {
    man = L{'Light Maneuver','Fire Maneuver', 'Wind Maneuver'},
    active = true,
    text = {text = {size=10}},
	sets = T{
		['caitdd'] = {'Light Maneuver', 'Fire Maneuver', 'Dark Maneuver'},
		['caitdd_overdrive'] = {'Light Maneuver', 'Fire Maneuver', 'Dark Maneuver'},
		
		['caittank'] = {'Light Maneuver', 'Fire Maneuver', 'Light Maneuver'},
		['caittank_overdrive'] = {'Light Maneuver', 'Fire Maneuver', 'Thunder Maneuver'},
		
		['Default'] = {'Light Maneuver', 'Fire Maneuver', 'Wind Maneuver'},
		['Default_overdrive'] = {'Light Maneuver', 'Fire Maneuver', 'Thunder Maneuver'},
		
		['dd'] = {'Light Maneuver', 'Fire Maneuver', 'Wind Maneuver'},
		['dd_overdrive'] = {'Light Maneuver','Fire Maneuver', 'Thunder Maneuver'},
		
		['ddtank'] = {'Light Maneuver', 'Fire Maneuver', 'Wind Maneuver'},
		['ddtank_overdrive'] = {'Light Maneuver','Fire Maneuver', 'Thunder Maneuver'},
		
		['turtle'] = {'Light Maneuver', 'Fire Maneuver', 'Water Maneuver'},
		['turtle_overdrive'] = {'Light Maneuver', 'Fire Maneuver', 'Water Maneuver'},
		
		['mdttank'] = {'Light Maneuver', 'Fire Maneuver', 'Water Maneuver'},
		['mdttank_overdrive'] = {'Light Maneuver', 'Fire Maneuver', 'Thunder Maneuver'},
		
		['sstank'] = {'Light Maneuver', 'Fire Maneuver', 'Wind Maneuver'},
		['sstank_overdrive'] = {'Light Maneuver', 'Fire Maneuver', 'Thunder Maneuver'},
		
		['spamdd'] = {'Wind Maneuver', 'Wind Maneuver', 'Wind Maneuver'},
		['spamdd_overdrive'] = {'Fire Maneuver', 'Wind Maneuver', 'Fire Maneuver'},
		
		['ranger'] = {'Wind Maneuver', 'Wind Maneuver', 'Wind Maneuver'},
		['ranger_overdrive'] = {'Fire Maneuver', 'Wind Maneuver', 'Fire Maneuver'},
		
		['boneslayer'] = {'Light Maneuver', 'Fire Maneuver', 'Wind Maneuver'},
		['boneslayer_overdrive'] = {'Light Maneuver', 'Fire Maneuver', 'Thunder Maneuver'},
		
		['whm'] = {'Light Maneuver', 'Light Maneuver', 'Dark Maneuver'},
		['whm_overdrive'] = {'Light Maneuver', 'Light Maneuver', 'Dark Maneuver'},
		
		['rdm'] = {'Light Maneuver', 'Dark Maneuver', 'Ice Maneuver'},
		['rdm_overdrive'] = {'Light Maneuver', 'Dark Maneuver', 'Ice Maneuver'},
		
		['blm'] = {'Light Maneuver', 'Dark Maneuver', 'Ice Maneuver'},
		['blm_overdrive'] = {'Light Maneuver', 'Dark Maneuver', 'Ice Maneuver'},
		
		['od'] = {'Light Maneuver', 'Fire Maneuver', 'Thunder Maneuver'},
		['od_overdrive'] = {'Light Maneuver', 'Fire Maneuver', 'Thunder Maneuver'},

		['skillup'] = {'Water Maneuver', 'Dark Maneuver', 'Ice Maneuver'},

	},
	repair = true,
	repairhpp = 40,
	repairoil = 'Automat. Oil +3',
	set = 'Default',
	deploy = false,
	activate = false,
	ignore_mobs = S{"Regiment's","Commander's","Leader's","Squadron's",},
	maintenance = false,
	remove_pet_debuffs = T{
		['petrification']=true,
		['Max_HP_Down']=false,
		['Magic_Def._Down']=false,
		['Defense_Down']=false,
		['Helix']=false,
		['Dia']=false,
		['Choke']=false,
		['VIT_Down']=false,
		['INT_Down']=false,
		['slow']=false,
		['bind']=false,
		['weight']=false,
		['AGI_Down']=false,
		['DEX_Down']=false,
		['MND_Down']=false,
		['CHR_Down']=false,
		['Max_MP_Down']=false,
		['Attack_Down']=false,
		['Accuracy_Down']=false,
		['Evasion_Down']=false,
		['Magic_Acc._Down']=false,
		['Magic_Atk._Down']=false,
		['Max_TP_Down']=false,
		['Elegy']=false,
		['Requiem']=false,
		['Burn']=false,
		['Frost']=false,
		['Rasp']=false,
		['Shock']=false,
		['Drown']=false,
		['Bio']=false,
	},
}
settings = config.load(default)

-- default to Automat. Oil +3 if the settings.repairoil is invalid.
if not settings.repairoil or settings.repairoil == '' or settings.repairoil == ' ' then
	settings.repairoil = 'Automat. Oil +3'
end

local puppet = {}
puppet.index = nil
puppet.id = nil
puppet.distance = nil
puppet.debuffs = S{}

ignore_buff_loss_zones = L{291, 289, 288}
zone = windower.ffxi.get_info().zone

multiman = ""
multimanCnt = 0

buffs = {}
force_target = nil

nexttime = os.clock()
del = 0

repair_oils = T{
	[0] = 'Automaton Oil',
	[1] = 'Automat. Oil +1',
	[2] = 'Automat. Oil +2',
	[3] = 'Automat. Oil +3',
}

pup_abilities = T{
    [135] = {id=135,en="Overdrive",recast_id=0},
    [136] = {id=136,en="Activate",recast_id=205},
    [137] = {id=137,en="Repair",recast_id=206},
    [138] = {id=138,en="Deploy",recast_id=207},
    [139] = {id=139,en="Deactivate",recast_id=208},
    [140] = {id=140,en="Retrieve",recast_id=209},
    [141] = {id=141,en="Fire Maneuver",recast_id=210},
    [142] = {id=142,en="Ice Maneuver",recast_id=210},
    [143] = {id=143,en="Wind Maneuver",recast_id=210},
    [144] = {id=144,en="Earth Maneuver",recast_id=210},
    [145] = {id=145,en="Thunder Maneuver",recast_id=210},
    [146] = {id=146,en="Water Maneuver",recast_id=210},
    [147] = {id=147,en="Light Maneuver",recast_id=210},
    [148] = {id=148,en="Dark Maneuver",recast_id=210},
	[309] = {id=309,en="Cooldown",recast_id=114},
    [310] = {id=310,en="Deus Ex Automata",recast_id=115},
	[322] = {id=322,en="Maintenance",recast_id=214},
} 


local display_box = function()
    local oil = settings.repairoil:sub(-1)
    if oil == 'l' then 
        oil = 'nq' 
    else 
        oil = '+'..oil 
    end

    local debuffs = ''
    if debugmode and puppet and puppet.debuffs then
        for debuff,_ in pairs(puppet.debuffs) do
            debuffs = debuffs..' '..debuff
        end
    end

    -- Calculate the length of the longest label
    local max_label_length = math.max(#'AutoPUP', #'Set:', #'Man 1:', #'Man 2:', #'Man 3:', #'Repair:', #'Activate:', #'Deploy:', #'Maintenance:', #'Target:')

    -- Calculate padding for the AutoPUP line
    local autopup_padding = string.rep(" ", max_label_length - #'AutoPUP')

    -- Define color based on actions state
    local autopup_color = actions and '0,255,0' or '255,0,0'
    local autopup_state = actions and 'ON' or 'OFF'

    -- Define colors for Activate, Deploy, and Maintenance states
    local activate_color = settings.activate and '0,255,0' or '255,0,0'
    local deploy_color = settings.deploy and '0,255,0' or '255,0,0'
    local maintenance_color = settings.maintenance and '0,255,0' or '255,0,0'

    -- Create formatted string with Widower syntax
    return string.format('AutoPUP%s  \\cs(%s)[%s]\\cr\nSet:%s  [%s]\nMan 1:%s  [%s]\nMan 2:%s  [%s]\nMan 3:%s  [%s]\nRepair:%s  \\cs(%s)[%s]\\cr \\cs(255,255,255)[%s] <= [%s]\\cr\nActivate:%s  \\cs(%s)[%s]\\cr\nDeploy:%s  \\cs(%s)[%s]\\cr\nMaintenance:%s  \\cs(%s)[%s]\\cr\n%s',
        autopup_padding, autopup_color, autopup_state,
        string.rep(" ", max_label_length - #'Set:'), settings.set,
        string.rep(" ", max_label_length - #'Man 1:'), settings.man[1],
        string.rep(" ", max_label_length - #'Man 2:'), settings.man[2],
        string.rep(" ", max_label_length - #'Man 3:'), settings.man[3],
        string.rep(" ", max_label_length - #'Repair:'), settings.repair and '0,255,0' or '255,0,0', settings.repair and 'ON' or 'OFF', oil, settings.repairhpp..'%',
        string.rep(" ", max_label_length - #'Activate:'), activate_color, settings.activate and 'ON' or 'OFF',
        string.rep(" ", max_label_length - #'Deploy:'), deploy_color, settings.deploy and 'ON' or 'OFF',
        string.rep(" ", max_label_length - #'Maintenance:'), maintenance_color, settings.maintenance and 'ON' or 'OFF',
        force_target and 'Target: '..force_target or '')
end





pup_status = texts.new(display_box(),settings.text,setting)
pup_status:show()

windower.register_event('prerender',function ()
	local play = windower.ffxi.get_player()
	if not play or play.main_job ~= 'PUP' or play.status > 1 then return end	
    if not actions then return end
	
    local curtime = os.clock()
    if nexttime + del <= curtime then
        nexttime = curtime
        del = 2
		buffs = play.buffs
		
		--return if: sleep, petrified, stun, charm, amnesia, charm, sleep
        if table.contains(buffs, 2) or table.contains(buffs, 7) or table.contains(buffs, 10) or table.contains(buffs, 14) 
		   or table.contains(buffs, 16) or table.contains(buffs, 17) or table.contains(buffs, 19) then 
			return 
		end
		
		local abil_recasts = windower.ffxi.get_ability_recasts()
		
		-- Activate
		local pet = windower.ffxi.get_mob_by_target('pet')
		if pet == nil then
			clear_puppet_info() -- clear puppet info
			
			if settings.activate then
				local activate = pup_abilities:with('en', 'Activate')
				local deus_ex_automata = pup_abilities:with('en', 'Deus Ex Automata')
				if activate and abil_recasts[activate.recast_id] and abil_recasts[activate.recast_id] == 0 then
					use_JA('/ja "'.. activate.en ..'" <me>')
				elseif deus_ex_automata and abil_recasts[deus_ex_automata.recast_id] and abil_recasts[deus_ex_automata.recast_id] == 0 then
					use_JA('/ja "'.. deus_ex_automata.en ..'" <me>')
				end
			end
			return 
		end
		puppet.index = pet.index
		puppet.id = pet.id
		
		-- Targeting
		if settings.deploy and pet.status == 0 then
			local targ_type = '<bt>'
			local target = windower.ffxi.get_mob_by_target('bt')
			if force_target then
				target = get_target(force_target)
				if target then
					set_target(target)
					targ_type = '<t>'
				end
			elseif not target or not valid_target(target) then
				target = get_party_target()
				if target then
					set_target(target)
					targ_type = '<t>'
				end
			end
				
			if target and target.hpp > 0 then
				local deploy = pup_abilities:with('en', 'Deploy')
				if deploy and abil_recasts[deploy.recast_id] and abil_recasts[deploy.recast_id] == 0 then
					use_PET(deploy.en, targ_type)
					return
				end
			end
		end
		
		puppet.distance = pet.distance:sqrt()
		
		-- Repair
		if pet and settings.repair and pet.hpp <= settings.repairhpp and puppet.distance < 23 and pet.status == 1 then
			local repair = pup_abilities:with('en', 'Repair')
			if abil_recasts[repair.recast_id] and abil_recasts[repair.recast_id] == 0 then
				windower.send_command("input /equip ammo '"..settings.repairoil.."';wait .5;input /ja '"..repair.en.."' <me>")
				return
			end
		end
		
		-- Maintenance
		if pet and settings.maintenance and table.length(puppet.debuffs) > 0 and puppet.distance < 23 then
			local maintenance = pup_abilities:with('en', 'Maintenance')
			if abil_recasts[maintenance.recast_id] and abil_recasts[maintenance.recast_id] == 0 then
				windower.send_command("input /equip ammo '"..settings.repairoil.."';wait .5;input /ja '"..maintenance.en.."' <me>")
				puppet.debuffs = S{}
				return
			end
		end
		
		-- set overdrive maneuver set
		if table.contains(buffs, res_buffs:with('en', 'Overdrive').id) and not settings.set:contains('_overdrive') then
			windower.send_command('pup set '..settings.set..'_overdrive')
			return
		end
		if not table.contains(buffs, res_buffs:with('en', 'Overdrive').id) and settings.set:contains('_overdrive') then
			settings.set = settings.set:gsub('_overdrive', '')
			windower.send_command('pup set '..settings.set)
			return
		end
		
		-- Overload
        if table.contains(buffs, res_buffs:with('en', 'Overload').id) and puppet.distance < 25 then 
			local cooldown = pup_abilities:with('en', 'Cooldown')
            if abil_recasts[cooldown.recast_id] and abil_recasts[cooldown.recast_id] == 0 then
                use_JA('/ja "'..cooldown.en..'" <me>')
            end
            return
        end
		
		-- Maneuver
		if abil_recasts[210] and abil_recasts[210] == 0 then
			for x = 1, #settings.man do
				local man = res_buffs:with('en', settings.man[x])
				if man then
					if not table.contains(buffs, man.id) then
						use_JA('/ja "%s" <me>':format(man.en))
						break
					end
					
					if multiman == settings.man[x] and countNumOfManeuvers(man.id) < multimanCnt then
						use_JA('/ja "%s" <me>':format(man.en))
						break
					end
				else
					windower.add_to_chat(9, 'Unknown maneuver: %s':format(settings.man[x]))
				end
			end
			return
		end
		
		pup_status:text(display_box())
    end
end)

function clear_puppet_info()
	puppet = {}
	puppet.index = nil
	puppet.id = nil
	puppet.distance = nil
	puppet.debuffs = S{}
	pup_status:text(display_box())
end

function countNumOfManeuvers(manBuffId)
	local count = 0
	for z = 1, #buffs do
		if buffs[z] == manBuffId then
			count = count + 1
		end
	end
	return count
end

function get_target(name)
	for i,v in pairs(windower.ffxi.get_mob_array()) do
		if v.valid_target and name:contains(v['name']) and v.hpp > 0 and math.sqrt(v.distance) < 25 then --math.sqrt(v.distance) < 49
			--log(v['name'], v['id'])
			return v
		end
	end
	
	return nil
end

function set_target(t)
	if not t then
		return
	end
	
	if t then
		local player = windower.ffxi.get_player()

		packets.inject(packets.new('incoming', 0x058, {
			['Player'] = player.id,
			['Target'] = t.id,
			['Player Index'] = player.index,
		}))
		
		--windower.add_to_chat(205, 'Set target to: '..t.name)
	end
end

function get_party_target()
	local member_ids = {}
	local party = windower.ffxi.get_party()
	
	for i = 0, 5 do
		local key = 'p%i':format(i % 6)
		local member = party[key]
		if member and member.mob then
			table.insert(member_ids, member.mob.id)
		end
	end

	local mob_arr = windower.ffxi.get_mob_array()
	for i,mob in pairs(mob_arr) do
		if mob and mob.is_npc and mob.claim_id > 0 and mob.hpp > 0 and valid_target(mob) then
			for _,pid in pairs(member_ids) do
				if mob.claim_id == pid then
					return mob
				end
			end
		end
	end
end

function valid_target(target)
	if target then
		for mobname in pairs(settings.ignore_mobs) do
			if target.name:contains(mobname) then
				return false
			end
		end
		return true
	end
	return false
end

windower.register_event('addon command', function(...)

	local function capitalize_first_letter(str)
		return str:gsub("^%l", string.upper)
	end

    local commands = {...}
    commands[1] = commands[1] and commands[1]:lower()
    if not commands[1] then
        actions = not actions
	elseif commands[1] == 'help' then
		showhelp()
    elseif commands[1] == 'on' then
        actions = true
		windower.add_to_chat(214, '---------------------- AutoPUP: [ON] -----------------------')
    elseif commands[1] == 'off' then
        actions = false
		windower.add_to_chat(214, '---------------------- AutoPUP: [OFF] ----------------------')
	elseif commands[1] == 'hide' then
		pup_status:hide()
		windower.add_to_chat(7, 'AutoPUP Hidden.')
	elseif commands[1] == 'show' then
		pup_status:show()
		windower.add_to_chat(7, 'AutoPUP Visible.')
	elseif commands[1] == 'deploy' then
        if settings.deploy == true then
			settings.deploy = false
		else
			settings.deploy = true
		end
		windower.add_to_chat(8, 'AutoPUP: Deploy = '..capitalize_first_letter(tostring(settings.deploy)))
	elseif commands[1] == 'activate' then
        if settings.activate == true then
			settings.activate = false
		else
			settings.activate = true
		end
		windower.add_to_chat(8, 'AutoPUP: Activate = '..capitalize_first_letter(tostring(settings.activate)))
	elseif commands[1] == 'repair' then
        if settings.repair == true then
			settings.repair = false
		else
			settings.repair = true
		end
		windower.add_to_chat(8, 'AutoPUP: Repair = '..capitalize_first_letter(tostring(settings.repair)))
	elseif commands[1] == 'maint' then
        if settings.maintenance == true then
			settings.maintenance = false
		else
			settings.maintenance = true
		end
		windower.add_to_chat(8, 'AutoPUP: Maintenance = '..capitalize_first_letter(tostring(settings.maintenance)))
	elseif commands[1] == 'target' or commands[1] == 'ft' then
		force_target = commands[2] and commands[2] or nil
		
	elseif commands[1] == 'repairhpp' then
		commands[2] = commands[2] and tonumber(commands[2])
        if commands[2] then
			settings.repairhpp = command[2]
		end
	elseif commands[1] == 'oil' then
		commands[2] = commands[2] and tonumber(commands[2])
        if commands[2] then
			newoil = repair_oils[commands[2]]
			settings.repairoil = newoil
			windower.add_to_chat(8, 'AutoPUP: Repair item set to: '..newoil)
		end
	elseif commands[1] == 'set' then
		if commands[2] then
			--print(dump(settings.sets))
			local newset = settings.sets[tostring(commands[2])]
			if newset then
				settings.set = tostring(commands[2])
				settings.man = newset
				setupMultiman(settings.man)
				windower.add_to_chat(8, 'AutoPUP: '..settings.set..' set loaded.')
			end
			
		end
	elseif commands[1] == 'mans' then
		if commands[2] then 
			setManeuver(1,commands[2])
			if commands[3] then 
				setManeuver(2,commands[3])
				if commands[3] then 
					setManeuver(3,commands[4]) 
				end
			end
		end
    elseif commands[1] == 'man' then
        commands[2] = commands[2] and tonumber(commands[2])
        if commands[2] and commands[3] then
            commands[3] = windower.convert_auto_trans(commands[3])
            for x = 3,#commands do commands[x] = commands[x]:ucfirst() end
            commands[3] = table.concat(commands, ' ', 3)
            
			local m = pup_abilities:with('en', commands[3])
            if m then
                settings.man[commands[2]] = m.en
				windower.add_to_chat(8, 'AutoPUP: ('..tostring(commands[2])..') '..m.en)
            else
				setManeuver(commands[2],commands[3])
            end
			
			setupMultiman(settings.man)
        end
    elseif commands[1] == 'save' then
        settings:save()
		windower.add_to_chat(8, 'AutoPUP: Saved Settings')
    elseif commands[1] == 'eval' then
        assert(loadstring(table.concat(commands, ' ',2)))()
    else
        showhelp()
    end
    pup_status:text(display_box())
end)

function setManeuver(num, str)
	for jaid,val in pairs(pup_abilities) do
		if val and val.en:startswith(str:ucfirst()) then
			settings.man[num] = val.en
		end
	end
end

windower.register_event('load', function()
	setupMultiman(settings.man)
	windower.add_to_chat(8, "AutoPUP: for commands use //pup help")
end)

function setupMultiman(arr)
	for _, m in ipairs(arr) do
		local tempcnt = 0
		for _, v in ipairs(arr) do
			if m == v then tempcnt = tempcnt + 1 end
		end
		if tempcnt > 1 then 
			multiman = m
			multimanCnt = tempcnt
			break
		else
			multiman = ''
			multimanCnt = 0
		end
	end
end

function use_JA(str)
    del = 1.2
    windower.chat.input(str)
end
function use_PET(str,ta)
    windower.send_command('input /pet "%s" %s':format(str,ta))
    del = 1.2
end

function showhelp()
	windower.add_to_chat(205, '    == AutoPUP :: HELP ==')
	windower.add_to_chat(207, ' //pup - toggles addon on/off')
	windower.add_to_chat(205, 'COMMAND: MAN')
	windower.add_to_chat(207, ' //pup mans {maneuver} {maneuver} {maneuver}')
	windower.add_to_chat(207, ' 	ex: //pup mans fire wind light')
	windower.add_to_chat(207, ' //pup man {#} {maneuver}')
	windower.add_to_chat(207, '   ex: //pup man 1 fire maneuver')
	windower.add_to_chat(207, '   ex: //pup man 2 wind')
	windower.add_to_chat(207, '   ex: //pup man 3 {Thunder Maneuver}')
	windower.add_to_chat(205, 'COMMAND: SET')
	windower.add_to_chat(207, ' //pup set {setname}')
	windower.add_to_chat(207, '   ex: //pup set spamdd')
	windower.add_to_chat(205, 'COMMAND: REPAIR / MAINTENANCE')
	windower.add_to_chat(207, ' //pup repair - turns auto repair on/off')
	windower.add_to_chat(207, ' //pup repairhpp {#}')
	windower.add_to_chat(207, ' //pup repairoil {#} - 0 through 3, ie: "pup repairoil 1" will use Automat. Oil +1')
	windower.add_to_chat(207, ' //pup maint - turns auto maintenance on/off')
	windower.add_to_chat(205, 'COMMAND: ACTIVATE & DEPLOY')
	windower.add_to_chat(207, ' //pup activate - turns auto activate on/off')
	windower.add_to_chat(207, ' //pup deploy - turns auto deploy on/off -- uses <bt> if not using \'ft\' (force target)')
	windower.add_to_chat(207, ' //pup ft "Name Of Mob" - Force Target: Sets a specific target to attack')
	windower.add_to_chat(205, 'COMMAND: SAVE')
	windower.add_to_chat(207, ' //pup save')
end

function reset()
    actions = false
    buffs = {}
	clear_puppet_info()
end

function status_change(new,old)
    if new > 1 and new < 4 then
        reset()
    end
end

function zone_change()
	zone = windower.ffxi.get_info().zone
	reset()
end

function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o..'\n')
    end
end

function lose_buff(buff_id)
	if buff_id == 143 and not ignore_buff_loss_zones:contains(zone) then
		reset()
	end
end

function handle_action(act)
	if not actions or not settings.maintenance then 
		puppet.debuffs = S{}
		return
	end
	
	local pet = windower.ffxi.get_mob_by_target('pet')
    if not pet then return end
	
	-- setting these incase this happens before being set in the main loop. ultimatly this probably isn't needed.
	puppet.id = pet.id
	puppet.index = pet.index
	
    for _,target in ipairs(act.targets) do
		if target and target.actions then
			for _,action in ipairs(target.actions) do
				if action and action.reaction == 24 and action.effect == 1 then
					if puppet.id == target.id and res_buffs[action.param] then
						local debuff_name = res_buffs[action.param].en:gsub(' ','_')
						local debuff_lname = res_buffs[action.param].enl:gsub(' ','_')
						
						if settings.remove_pet_debuffs[debuff_name] or settings.remove_pet_debuffs[debuff_lname] then
							puppet.debuffs:add(debuff_name)
						end
						if debugmode then 
							windower.add_to_chat(207, 'AutoPUP: Puppet has debuff:'..debuff_name)
							pup_status:text(display_box())
						end
					end
				end
			end
		end
    end
end


-- Register Windower Events -- 
windower.register_event('action', handle_action)

windower.register_event('lose buff', lose_buff)

windower.register_event('status change', status_change)

windower.register_event('zone change', zone_change)

windower.register_event('job change', function()
    local player = windower.ffxi.get_player()
    if player then
        local mainjob = player.main_job
        if mainjob == 'PUP' or player.sub_job == 'PUP' then
            pup_status:show()
        else
            pup_status:hide()
        end
    else
        pup_status:hide()
    end
end)

windower.register_event('logout', zone_change)

windower.register_event('login', function()
    local player = windower.ffxi.get_player()
    if player then
        local mainjob = player.main_job
        if mainjob == 'PUP' or player.sub_job == 'PUP' then
            pup_status:show()
        else
            pup_status:hide()
        end
    else
        pup_status:hide()
    end
end)

windower.register_event('load', function()
    local player = windower.ffxi.get_player()
    if player then
        local mainjob = player.main_job
        if mainjob == 'PUP' or player.sub_job == 'PUP' then
            pup_status:show()
        else
            pup_status:hide()
        end
    else
        pup_status:hide()
    end
end)
