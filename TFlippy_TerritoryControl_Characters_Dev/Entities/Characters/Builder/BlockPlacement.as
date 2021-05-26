#include "PlacementCommon.as"
#include "BuildBlock.as"
#include "Requirements.as"
#include "GameplayEvents.as"
#include "DeityCommon.as"

//server-only
void PlaceBlock(CBlob@ this, u8 index, Vec2f cursorPos)
{
	BuildBlock @bc = getBlockByIndex(this, index);

	if (bc is null)
	{
		warn("BuildBlock is null " + index);
		return;
	}

	CBitStream missing;

	CInventory@ inv = this.getInventory();
	if (bc.tile > 0 && hasRequirements(inv, bc.reqs, missing))
	{
		bool take = true;
		
		u8 deity_id = this.get_u8("deity_id");
		switch (deity_id)
		{
			case Deity::mason:
			{
				CBlob@ altar = getBlobByName("altar_mason");
				if (altar !is null)
				{
					//print("free block chance: " + Maths::Min((altar.get_f32("deity_power") * 0.01f),MAX_FREE_BLOCK_CHANCE));
					if (XORRandom(100) < Maths::Min((altar.get_f32("deity_power") * 0.01f),MAX_FREE_BLOCK_CHANCE))
					{
						take = false;
						// print("free block!");		
					}
					else
					{
						altar.add_f32("deity_power", 1);
						if (isServer()) altar.Sync("deity_power", false);
					}
				}
			}
		
			case Deity::foghorn:
			{
				if (getMap().isBlobWithTagInRadius("upf property", cursorPos, 128))
				{
					CBlob@ altar = getBlobByName("altar_foghorn");
					if (altar !is null)
					{
						f32 reputation_penalty = 10.00f;
						if (isClient())
						{
							if (this.isMyPlayer()) 
							{
								client_AddToChat("You have tampered with UPF property! (" + -reputation_penalty + " reputation)", 0xffff0000);
								Sound::Play("Collect.ogg", cursorPos, 2.00f, 0.80f);
							}
						}
						
						altar.add_f32("deity_power", -reputation_penalty);
						if (isServer()) altar.Sync("deity_power", false);
					}
				}
			}
		break;
		}
		
		if (take)
		{
			server_TakeRequirements(inv, bc.reqs);
		}
		
		getMap().server_SetTile(cursorPos, bc.tile);

		SendGameplayEvent(createBuiltBlockEvent(this.getPlayer(), bc.tile));
	}
}

void onInit(CBlob@ this)
{
	AddCursor(this);
	SetupBuildDelay(this);
	this.addCommandID("placeBlock");

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	this.getCurrentScript().removeIfTag = "dead";
}

void onTick(CBlob@ this)
{
	if (this.isInInventory())
	{
		return;
	}

	//don't build with menus open
	if (getHUD().hasMenus())
	{
		return;
	}

	CBlob @carryBlob = this.getCarriedBlob();
	if (carryBlob !is null)
	{
		return;
	}

	if (isBuildDelayed(this))
	{
		return;
	}

	BlockCursor @bc;
	this.get("blockCursor", @bc);
	if (bc is null)
	{
		return;
	}

	SetTileAimpos(this, bc);
	// check buildable
	bc.buildable = false;
	bc.supported = false;
	bc.hasReqs = false;
	TileType buildtile = this.get_TileType("buildtile");

	if (buildtile > 0)
	{
		bc.blockActive = true;
		bc.blobActive = false;
		CMap@ map = this.getMap();
		u8 blockIndex = getBlockIndexByTile(this, buildtile);
		BuildBlock @block = getBlockByIndex(this, blockIndex);
		if (block !is null)
		{
			bc.missing.Clear();
			bc.hasReqs = hasRequirements(this.getInventory(), block.reqs, bc.missing);
		}

		if (bc.cursorClose)
		{
			Vec2f halftileoffset(map.tilesize * 0.5f, map.tilesize * 0.5f);
			bc.buildableAtPos = isBuildableAtPos(this, bc.tileAimPos + halftileoffset, buildtile, null, bc.sameTileOnBack);
			//printf("bc.buildableAtPos " + bc.buildableAtPos );
			bc.rayBlocked = isBuildRayBlocked(this.getPosition(), bc.tileAimPos + halftileoffset, bc.rayBlockedPos);
			bc.buildable = bc.buildableAtPos && !bc.rayBlocked;

			bc.supported = bc.buildable && map.hasSupportAtPos(bc.tileAimPos);
		}

		// place block

		if (!getHUD().hasButtons() && (this.isKeyPressed(key_action1) && !this.hasTag("noLMB")))
		{
			if (bc.cursorClose && bc.buildable && bc.supported)
			{
				CBitStream params;
				params.write_u8(blockIndex);
				params.write_Vec2f(bc.tileAimPos);
				this.SendCommand(this.getCommandID("placeBlock"), params);
				u32 delay = this.get_u32("build delay");
				SetBuildDelay(this, delay);
				bc.blockActive = false;
			}
			else if ((this.isKeyJustPressed(key_action1) && !this.hasTag("noLMB")) && !bc.sameTileOnBack)
			{
				Sound::Play("NoAmmo.ogg");
			}
		}
	}
	else
	{
		bc.blockActive = false;
	}
}

// render block placement

void onInit(CSprite@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	this.getCurrentScript().removeIfTag = "dead";
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if (getHUD().hasButtons())
	{
		return;
	}

	if (blob.isKeyPressed(key_action2) || blob.isKeyPressed(key_pickup))   //hack: dont show when builder is attacking
	{
		return;
	}

	CBlob @carryBlob = blob.getCarriedBlob();
	if (carryBlob !is null)
	{
		return;
	}

	if (isBuildDelayed(blob))
	{
		return;
	}

	// draw a map block or other blob that snaps to grid
	TileType buildtile = blob.get_TileType("buildtile");

	if (buildtile > 0)
	{
		CMap@ map = getMap();
		BlockCursor @bc;
		blob.get("blockCursor", @bc);

		if (bc !is null)
		{
			if (bc.cursorClose && bc.hasReqs && bc.buildable)
			{
				SColor color;

				if (bc.buildable && bc.supported)
				{
					color.set(255, 255, 255, 255);
					map.DrawTile(bc.tileAimPos, buildtile, color, getCamera().targetDistance, false);
				}
				else
				{
					// no support
					color.set(255, 255, 46, 50);
					const u32 gametime = getGameTime();
					Vec2f offset(0.0f, -1.0f + 1.0f * ((gametime * 0.8f) % 8));
					map.DrawTile(bc.tileAimPos + offset, buildtile, color, getCamera().targetDistance, false);

					if (gametime % 16 < 9)
					{
						Vec2f supportPos = bc.tileAimPos + Vec2f(blob.isFacingLeft() ? map.tilesize : -map.tilesize, map.tilesize);
						Vec2f point;
						if (map.rayCastSolid(supportPos, supportPos + Vec2f(0.0f, map.tilesize * 32.0f), point))
						{
							const uint count = (point - supportPos).getLength() / map.tilesize;
							for (uint i = 0; i < count; i++)
							{
								map.DrawTile(supportPos + Vec2f(0.0f, map.tilesize * i), buildtile,
								             SColor(255, 205, 16, 10),
								             getCamera().targetDistance, false);
							}
						}
					}
				}
			}
			else
			{
				f32 halfTile = map.tilesize / 2.0f;
				Vec2f aimpos = blob.getAimPos();
				Vec2f offset(-0.2f + 0.4f * ((getGameTime() * 0.8f) % 8), 0.0f);
				map.DrawTile(Vec2f(aimpos.x - halfTile, aimpos.y - halfTile) + offset, buildtile,
				             SColor(255, 255, 46, 50),
				             getCamera().targetDistance, false);
			}
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (isServer() && cmd == this.getCommandID("placeBlock"))
	{
		u8 index = params.read_u8();
		Vec2f pos = params.read_Vec2f();
		PlaceBlock(this, index, pos);
	}
}

