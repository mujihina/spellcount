--[[
spellcount v2.1

Copyright © 2019, Mujihina
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
* Neither the name of spellcount nor the
names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Mujihina BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]


_addon.name    = 'spellcount'
_addon.author  = 'Mujihina'
_addon.version = '2.1'
_addon.commands = {'spellcount', 'sc'}


-- Required libraries
-- luau
-- resources.spells
-- texts
require ('luau')
spells = require ('resources').spells
jobs = require ('resources').jobs
monster_abilities = require ('resources').monster_abilities

packets = require ('packets')

local myspells = T{}
local spell_count = 0


local detected_path = "c:/Program Files (x86)/windower4/addons/spellcount/nuclearlaunchdetected.wav"
local evolution_path = "c:/Program Files (x86)/windower4/addons/spellcount/evolutioncomplete.wav"


-- List of job abbreviations and ids
local job_names = S{}
for i,j in pairs(jobs) do
	job_names[j.ens:lower()] = i
end


-- Load Defaults
function load_spells()
    if (not windower.ffxi.get_info().logged_in) then return end

    spell_count = 0
    myspells = windower.ffxi.get_spells()
    for i,j in pairs (myspells) do
      if (j) then 
           spell_count = spell_count + 1
      end
    end
    print ("Spells known: %d":format(spell_count))
end       


function check_spells()
    if (not windower.ffxi.get_info().logged_in) then return end

    myspells = windower.ffxi.get_spells()
    tmp_count = 0
    for i,j in pairs (myspells) do
        if (j == true) then tmp_count = tmp_count + 1 end
    end
    if (tmp_count ~= spell_count) then
       print ("spellcount: NEW spell count: %d":format(tmp_count))
       windower.play_sound(evolution_path)
       spell_count = tmp_count
    end
end       


function check_action (id, original, modified, injected, blocked)
    if (id == 0x028) then
        local p = packets.parse ('incoming', original)
        local cat = p['Category']
        if (cat ~= 7) then return end
        local tpmove_id = p['Target 1 Action 1 Param']
        if (monster_abilities[tpmove_id]) then
            local tpmove_name = monster_abilities[tpmove_id].name
            local spell = spells:with('en', tpmove_name)
            if spell and spells.type == 'BlueMagic' then
                if (myspells[spell.id]) then
                    print ("spellcount: Already know '%s'":format(tpmove_name))
                else
                    print ("spellcount: Trying to learn '%s'":format(tpmove_name))
                    windower.play_sound(detected_path)
                end                                
            end
        end     
    end

    -- Spell list
	if id == 0xAA then check_spells() end
end

-- Show syntax
function show_syntax()
    windower.add_to_chat (200, 'sc: Syntax is:')
    windower.add_to_chat (207, '    \'sc <JOB>|trusts|missing|<string>\'')
end


function sc_command (...)
    local cmd = L{...}
	cmd = cmd:concat(' '):lower():stripchars(',"'):spaces_collapse()
    if cmd == 'help' or cmd:length() == 0 then
        show_syntax()
        return
    end
    local my_spells = windower.ffxi.get_spells()

    -- check jobs
    if job_names[cmd] then
    	job_id = job_names[cmd]
    	local missing_spells = S{}
    	local missing_levels = S{}
    	local spells_total = 0
    	windower.add_to_chat (200, 'SC: Looking up %s spells':format(cmd))	
		for spell_id,spell in pairs(res.spells) do
			-- skip trusts, trusts spells and unlearnable spells
			if spell.levels[job_id] and spell.type ~= 'Trust' and not spell.unlearnable then
				spells_total = spells_total + 1
				-- skip learned spells
				if not my_spells[spell_id]  then
					if not missing_spells[spell.levels[job_id]] then
						missing_spells[spell.levels[job_id]] = S{}
					end
					missing_spells[spell.levels[job_id]]:add(spell_id)
					missing_levels:add(spell.levels[job_id])
		        end
		    end
	    end
	    -- sort by level/jp and print
	    local missing_total = 0
	    for _, level in ipairs(missing_levels:sort()) do
	    	local missing_string = nil
	    	for i in pairs(missing_spells[level]) do
	    		missing_total = missing_total + 1
	    		if missing_string == nil then
	    			missing_string = spells[i].name
	    		else
	    			missing_string = '%s, %s':format(missing_string, spells[i].name)
	    		end
	    	end
	    	if level < 99 then
		    	windower.add_to_chat (207, 'Lv %d: %s':format(level, missing_string))
		    else
		    	windower.add_to_chat (207, '%d JP: %s':format(level, missing_string))
		    end
	    end
		windower.add_to_chat (200, 'Missing spells for %s: %d out of %d':format(cmd, missing_total, spells_total))
    	return
    end
	
	-- trusts
	if cmd == 'trusts' then
	    local missing_total = 0
	    local spells_total = 0
		windower.add_to_chat (200, 'SC: Looking up Trusts spells')	
		for spell_id,spell in pairs(res.spells) do
			-- skip UC trusts
			if spell.type == 'Trust' and not spell.name:contains('(UC)') then
				spells_total = spells_total +1
				if not my_spells[spell_id] then
					missing_total = missing_total + 1
			    	windower.add_to_chat (207, '%s':format(spell.name))
			    end
			end
		end
		windower.add_to_chat (200, 'Missing trusts: %d out of %d':format(missing_total, spells_total))
		return
	end

	if cmd == 'missing' then
		windower.add_to_chat (200, 'SC: Searching spells for missing spells')
		local missing_total = 0
		local spells_total = 0
		for spell_id,spell in pairs(res.spells) do
			if not spell.name:contains('(UC)')  then
				spells_total = spells_total + 1
				if not my_spells[spell_id] then
			    	missing_total = missing_total + 1
			    	windower.add_to_chat (207, '    Unknown: %s (%s)':format(spell.name, spell.type))
				end
			end
		end
		windower.add_to_chat (200, 'Missing matched spells: %d out of %d':format(missing_total, spells_total))	
		return
	end

	-- search strings
	windower.add_to_chat (200, 'SC: Searching spells for "%s"':format(cmd))
	local missing_total = 0
	local spells_total = 0
	for spell_id,spell in pairs(res.spells) do
		if spell.name:lower():contains(cmd) and not spell.name:contains('(UC)')  then
			spells_total = spells_total + 1
			if my_spells[spell_id] then
		    	windower.add_to_chat (200, '    Known: %s (%s)':format(spell.name, spell.type))
		    else
		    	missing_total = missing_total + 1
		    	windower.add_to_chat (207, '    Unknown: %s (%s)':format(spell.name, spell.type))
			end
		end
	end
	windower.add_to_chat (200, 'Missing matched spells: %d out of %d':format(missing_total, spells_total))

end


-- Register callbacks
windower.register_event ('load', 'login', load_spells)
windower.register_event ('incoming chunk', check_action)
windower.register_event ('addon command', sc_command)
