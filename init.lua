
--[[
    Inspector tool for rollback file
    Intended as a faster replacement for rollback_check.

    Copyright (C) 2013 Sokomine

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

-- Version 1.0

-- Changelog: 
    
local inspector = {};

inspector.rollback_file = 'rollback.txt';

inspector.show_max_amount   = '20'; -- important for doors etc - they change a lot
inspector.grep_before_after = '10'; -- list that many actions of the player around the given timestamp

-- store the results of the last check for futher inspections about what the selected player did around that time
inspector.last_checks = {};


-- value is the search result as returned by the shell command (mostly grep)
-- sx, xy, sz are the position where the search was done; they are used for the header only
-- time_now is os.time() or another timestamp actions ought to be compared against
-- mode: if 0: list and number all actors and actions on a specific node
--       if 1: list the actions of a player
-- spname: the name of the player whos actions are listed (only relevant for the header)
-- this_player_name is the name of the player/moderator who initiated the search
inspector.print_nice = function( data )

  value    = data.value;
  sx       = data.sx;
  sy       = data.sy;
  sz       = data.sz;
  time_now = data.time_now;
  mode     = data.mode;
  spname   = data.spname;
  this_player_name = data.this_player_name;
  anz_versuche     = data.anz_versuche;

--print("Got: "..tostring( value));

   -- TODO: what if the player got lost?
   
   local f, err = io.open( '/tmp/mt.inspector.mode'..mode..'.'..this_player_name, "rb")
--  minetest.chat_send_player( this_player_name,  'Looking for /tmp/mt.inspector.mode'..mode..'.'..this_player_name );
   if err ~= nil then
      if( anz_versuche > 20 ) then -- TODO
         minetest.chat_send_player( this_player_name, 'Analysis of this possible griefing action finally failed or took too long.');
         return
      end

      minetest.chat_send_player( this_player_name, 'Trying later.');

      data.anz_versuche = data.anz_versuche + 1;
      minetest.after( 2, inspector.print_nice,  data );
      return;
   end

   if( not( f ) or f == nil) then
      minetest.chat_send_player( this_player_name, 'No results found for position '..tostring(sx)..','..tostring(sy)..','..tostring(sz)..'.');
      return;
   end

   local s = assert(f:read('*a'))
   value = s;
   f:close()

   local i = 0;

   local txt = 'Analysis of ';
   if(     mode==1 ) then
      txt = txt..'node at ('..tostring(sx)..','..tostring(sy)..','..tostring(sz)..'):\n';

      -- reset last checks done by this player
      inspector.last_checks[ this_player_name ] = {};

   elseif( mode==2 ) then
      txt = txt..'actions of player '..tostring( spname )..' at/around timeindex '..tostring( time_now )..':\n';
   end

   local nothing_found = '  Sorry, no recorded actions found.';
   for timestamp, pname, x, y, z, old_node, old_p1, old_p2, old_meta, new_node, new_p1, new_p2, new_meta, guessed in
         value:gmatch( '(%d+) "player:([^\"]+)" %[set_node %(([+-]?%d+)%,([+-]?%d+)%,([+-]?%d+)%) "([^\"]+)" (%d+) (%d+) "([^\"]*)" "([^\"]+)" (%d+) (%d+) "([^\"]*)"%]([^\n]*)[\n\r]') do


      nothing_found = ''; -- we DID found something

      if( timestamp and pname ) then
--         print( 'when: '..tostring( timestamp )..' pname: '..tostring( pname )..' at: '..tostring(x)..':'..tostring(y)..':'..tostring(z)..
--           ' old node: '..tostring( old_node )..' old_p1: '..tostring( old_p1 )..' old_p2: '..tostring( old_p2 )..' old_meta: '..tostring( old_meta )..
--           ' new node: '..tostring( new_node )..' new_p1: '..tostring( new_p1 )..' new_p2: '..tostring( new_p2 )..' new_meta: '..tostring( new_meta ));
 
         -- add tags/indices so that actions of that player can be inspected more closely
         if( mode==1 ) then
            i = i+1;
            txt = txt..'   ['..tostring( i )..'] ';

            -- stor time and playername for later usage
            inspector.last_checks[ this_player_name ][ i ] = tostring( timestamp )..' '..tostring( pname );
            --inspector.last_checks[ this_player_name ][ i ] = tostring( timestamp )..' "player:'..tostring( pname )..'" [set_node ';
         end

         if( guessed and guessed ~= '') then
            guessed = ' ('..guessed..') ';
         else
            guessed = '';
         end

         txt = txt..'   '..tostring( time_now - timestamp )..'s ago: '..tostring( pname )..guessed;
         if(     new_node == 'air' and old_node ~= 'air' ) then
            txt = txt..' digged '..tostring( old_node );
         elseif( new_node ~= 'air' and old_node == 'air' ) then
            txt = txt..' placed '..tostring( new_node );
         elseif( new_node == old_node ) then
            txt = txt..'modified '..tostring( new_node );
         else
            txt = txt..' changed '..tostring( old_node )..' into '..tostring( new_node );
         end

         if( mode==2 ) then
            txt = txt..' at '..tostring(x)..','..tostring(y)..','..tostring(z)..'\n';
         else
            txt = txt..'\n';
         end
      end
   end
   -- tell the player the result of the command
   minetest.chat_send_player( this_player_name, txt..nothing_found ); 
   --print('Actions of player: '..table.concat( inspector.last_checks[ this_player_name ] or {}, ', ' )); 
end



-- search who digged/placed/changed/otherwise modified this node
inspector.search_node = function( x,y,z, this_player_name )

  -- make sure a number is passed
  if(    x and type(x)=='number' and x>-31000 and x<31000 
     and y and type(y)=='number' and y>-31000 and y<31000
     and z and type(z)=='number' and z>-31000 and z<31000 ) then

      -- execute the command in the background
      os.execute( minetest.get_modpath("inspector")..'/grep.search_by_pos '..
                  tostring( x )..' '..tostring( y )..' '..tostring( z )..' '..tostring( inspector.show_max_amount )..' '..this_player_name..' &' );
    
      minetest.after( 2, inspector.print_nice, {value=s, sx=x, sy=y, sz=z, time_now=os.time(), mode=1, spname=nil, this_player_name=this_player_name, anz_versuche=0 });

   else
      return "ERROR";
   end
end



-- search what else the player did around the time when he changed the last inspected node
inspector.search_player_actions = function( time, pname, this_player_name )

  -- make sure a number is passed
   if( time and pname ) then

      -- show 5 actions of this player prior and after the specified time
      os.execute( minetest.get_modpath("inspector")..'/grep.search_by_name '..
                  tostring( pname )..' '..tostring( inspector.grep_before_after )..' '..tostring( time )..' '..tostring( this_player_name )..' &');

      minetest.after( 2, inspector.print_nice, { value=s, sx=0,sy=0,sz=0, time_now=time, mode=2, spname=pname, this_player_name=this_player_name, anz_versuche=0 });

   else
      return "ERROR";
   end
end


-- interface for inspector.search_player_actions
inspector.inspect = function( id, this_player_name )

  local txt = '';

  if( not( inspector.last_checks[ this_player_name ] )) then
     txt = 'Please analyze a node first.';
  elseif( not(id) or id == 0 or id=='') then
     txt = 'Please select a number to list further actions of that player around that time:\n';
     for i,v in ipairs( inspector.last_checks[ this_player_name ]) do
        txt = txt..'   ['..tostring( i )..'] '..v..'\n';
     end
  elseif( tonumber(id) < 1 or not( inspector.last_checks[ this_player_name ] ) or not( inspector.last_checks[ this_player_name ][ tonumber(id) ]) ) then
     txt = 'Action number '..tostring( id )..': No matching entry found.'; 
  else
     local help = inspector.last_checks[ this_player_name ][ tonumber(id) ];
     for wann, wer in help:gmatch( "(%d+) (.+)" ) do
        inspector.search_player_actions( wann, wer, this_player_name );
     end
  end
  minetest.chat_send_player( this_player_name, txt ); 
end




minetest.register_chatcommand("inspect", {
	params = "<action nr>",
	description = "List detailed actions of a given player at/around a given timestamp. "..
                      "Playername and timestamp are derived from previous checks with the corresponding tool. "..
                      "<action nr> selects one of the actions reported by such a check.",
	privs = {rollback=true},
	func = function(name, param)

                  inspector.inspect( param, name );
                  return;
               end,
})

          
-- create the tool that will help to fascilitate checks
minetest.register_tool( "inspector:inspector",
{
    description = "Rollback check tool",
    groups = {}, 
    inventory_image = "default_tool_woodaxe.png", -- TODO
    wield_image = "",
    wield_scale = {x=1,y=1,z=1},
    stack_max = 1, -- there is no need to have more than one
    liquids_pointable = true, -- sometimes liquids have to be checked as well
    -- the tool_capabilities are completely irrelevant here
    tool_capabilities = {
        full_punch_interval = 1.0,
        max_drop_level=0,
        groupcaps={
            fleshy={times={[2]=0.80, [3]=0.40}, maxwear=0.05, maxlevel=1},
            snappy={times={[2]=0.80, [3]=0.40}, maxwear=0.05, maxlevel=1},
            choppy={times={[3]=0.90}, maxwear=0.05, maxlevel=0}
        }
    },
    node_placement_prediction = nil,

    on_place = function(itemstack, placer, pointed_thing)

       if( placer == nil or pointed_thing == nil) then
          return itemstack; -- nothing consumed
       end
       local name = placer:get_player_name();

       -- the tool exists so that we can get positions for the search - the pos is the most important value here
       local pos  = minetest.get_pointed_thing_position( pointed_thing, under );
       
       if( not( pos ) or not( pos.x )) then
          minetest.chat_send_player( name, "Position not found.");
          return;
       end
       inspector.search_node( pos.x, pos.y, pos.z, name );

       return itemstack; -- nothing consumed, nothing changed
    end,
     
--    on_drop = func(itemstack, dropper, pos),

    on_use = function(itemstack, placer, pointed_thing)

       if( placer == nil or pointed_thing == nil) then
          return itemstack; -- nothing consumed
       end
       local name = placer:get_player_name();

       local pos  = minetest.get_pointed_thing_position( pointed_thing, under );
       
       if( not( pos ) or not( pos.x )) then
          minetest.chat_send_player( name, "Position not found.");
          return;
       end
       inspector.search_node( pos.x, pos.y, pos.z, name );

       return itemstack; -- nothing consumed, nothing changed
    end,
})

