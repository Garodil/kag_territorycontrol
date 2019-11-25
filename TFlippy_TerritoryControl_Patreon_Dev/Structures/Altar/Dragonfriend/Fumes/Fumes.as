void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(true);
	this.addCommandID("consume");
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	CBitStream params;
	params.write_u16(caller.getNetworkID());
	caller.CreateGenericButton(22, Vec2f(0, 0), this, this.getCommandID("consume"), "Smoke!", params);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("consume"))
	{
		this.getSprite().PlaySound("gasp.ogg");
		this.getSprite().PlaySound("DrugLab_Create_Gas.ogg", 0.40f, 0.60f);

		CBlob@ caller = getBlobByNetworkID(params.read_u16());
		if (caller !is null)
		{		
			if (!caller.hasScript("Fumes_Effect.as")) caller.AddScript("Fumes_Effect.as");			
			caller.add_f32("fumes_effect", 1);
			
			caller.set_u32("nextDragonFireball", getGameTime());

			if (isClient())
			{	
				if (caller.isMyPlayer())
				{
					SetScreenFlash(255, 0, 0, 0, 1);
				}
				
				ParticleAnimated("LargeSmoke", this.getPosition(), Vec2f(0.5f, -0.75f), 0, 1.00f, 3 + XORRandom(2), 0, false);
			
				// Sound::Play("MLG_Airhorn.ogg");
				// getMap().CreateSkyGradient("skygradient_Fumes.png");
				
				// CSprite@ sprite = caller.getSprite();
				// sprite.SetEmitSound("AltarSwagLag_Music.ogg");
				// sprite.SetEmitSoundVolume(1.00f);
				// sprite.SetEmitSoundSpeed(1.00f);
				// sprite.SetEmitSoundPaused(false);
			}
			
			

			if (isServer())
			{
				this.server_Die();
			}
		}
	}
}
