#pragma semicolon 1
#pragma newdecls required

static const char g_DeathSounds[][] = {
	"vo/heavy_paincrticialdeath01.mp3",
	"vo/heavy_paincrticialdeath02.mp3",
	"vo/heavy_paincrticialdeath03.mp3",
};

static const char g_HurtSounds[][] = {
	"vo/heavy_painsharp01.mp3",
	"vo/heavy_painsharp02.mp3",
	"vo/heavy_painsharp03.mp3",
	"vo/heavy_painsharp04.mp3",
	"vo/heavy_painsharp05.mp3",
};


static const char g_IdleAlertedSounds[][] = {
	"vo/taunts/heavy_taunts16.mp3",
	"vo/taunts/heavy_taunts18.mp3",
	"vo/taunts/heavy_taunts19.mp3",
};

static const char g_MeleeAttackSounds[][] = {
	"weapons/pickaxe_swing1.wav",
	"weapons/pickaxe_swing2.wav",
	"weapons/pickaxe_swing3.wav",
};

static const char g_MeleeHitSounds[][] = {
	"mvm/melee_impacts/cbar_hitbod_robo01.wav",
	"mvm/melee_impacts/cbar_hitbod_robo02.wav",
	"mvm/melee_impacts/cbar_hitbod_robo03.wav",
};


static float RajulHealAlly[MAXENTITIES];
static float RajulHealAllyCooldownAntiSpam[MAXENTITIES];
static int RajulHealAllyDone[MAXENTITIES];

void WinterArcticMage_OnMapStart_NPC()
{
	for (int i = 0; i < (sizeof(g_DeathSounds));	   i++) { PrecacheSound(g_DeathSounds[i]);	   }
	for (int i = 0; i < (sizeof(g_HurtSounds));		i++) { PrecacheSound(g_HurtSounds[i]);		}
	for (int i = 0; i < (sizeof(g_IdleAlertedSounds)); i++) { PrecacheSound(g_IdleAlertedSounds[i]); }
	for (int i = 0; i < (sizeof(g_MeleeAttackSounds)); i++) { PrecacheSound(g_MeleeAttackSounds[i]); }
	for (int i = 0; i < (sizeof(g_MeleeHitSounds)); i++) { PrecacheSound(g_MeleeHitSounds[i]); }
	PrecacheModel("models/player/medic.mdl");
}


methodmap WinterArcticMage < CClotBody
{
	public void PlayIdleAlertSound() 
	{
		if(this.m_flNextIdleSound > GetGameTime(this.index))
			return;
		
		EmitSoundToAll(g_IdleAlertedSounds[GetRandomInt(0, sizeof(g_IdleAlertedSounds) - 1)], this.index, SNDCHAN_VOICE, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME);
		this.m_flNextIdleSound = GetGameTime(this.index) + GetRandomFloat(12.0, 24.0);
		
	}
	
	public void PlayHurtSound() 
	{
		if(this.m_flNextHurtSound > GetGameTime(this.index))
			return;
			
		this.m_flNextHurtSound = GetGameTime(this.index) + 0.4;
		
		EmitSoundToAll(g_HurtSounds[GetRandomInt(0, sizeof(g_HurtSounds) - 1)], this.index, SNDCHAN_VOICE, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME);
		
	}
	
	public void PlayDeathSound() 
	{
		EmitSoundToAll(g_DeathSounds[GetRandomInt(0, sizeof(g_DeathSounds) - 1)], this.index, SNDCHAN_VOICE, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME);
	}
	
	public void PlayMeleeSound()
	{
		EmitSoundToAll(g_MeleeAttackSounds[GetRandomInt(0, sizeof(g_MeleeAttackSounds) - 1)], this.index, SNDCHAN_AUTO, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME);
	}
	public void PlayMeleeHitSound() 
	{
		EmitSoundToAll(g_MeleeHitSounds[GetRandomInt(0, sizeof(g_MeleeHitSounds) - 1)], this.index, SNDCHAN_STATIC, RAIDBOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);

	}
	
	
	public WinterArcticMage(int client, float vecPos[3], float vecAng[3], bool ally)
	{
		WinterArcticMage npc = view_as<WinterArcticMage>(CClotBody(vecPos, vecAng, "models/player/heavy.mdl", "1.5", "10000", ally, false, true));
		
		i_NpcInternalId[npc.index] = INTERITUS_WINTER_ARCTIC_MAGE;
		i_NpcWeight[npc.index] = 1;
		FormatEx(c_HeadPlaceAttachmentGibName[npc.index], sizeof(c_HeadPlaceAttachmentGibName[]), "head");
		
		int iActivity = npc.LookupActivity("ACT_MP_RUN_MELEE_ALLCLASS");
		if(iActivity > 0) npc.StartActivity(iActivity);
		
		
		npc.m_flNextMeleeAttack = 0.0;
		
		npc.m_iBleedType = BLEEDTYPE_NORMAL;
		npc.m_iStepNoiseType = STEPSOUND_GIANT;	
		npc.m_iNpcStepVariation = STEPTYPE_NORMAL;
		RajulHealAlly[npc.index] = 0.0;
		RajulHealAllyCooldownAntiSpam[npc.index] = 0.0;

		func_NPCDeath[npc.index] = view_as<Function>(WinterArcticMage_NPCDeath);
		func_NPCOnTakeDamage[npc.index] = view_as<Function>(WinterArcticMage_OnTakeDamage);
		func_NPCThink[npc.index] = view_as<Function>(WinterArcticMage_ClotThink);
		
		//IDLE
		npc.m_iState = 0;
		npc.m_flGetClosestTargetTime = 0.0;
		npc.StartPathing();
		npc.m_flSpeed = 250.0;
		
		
		int skin = 1;
		SetEntProp(npc.index, Prop_Send, "m_nSkin", skin);
		

		npc.m_iWearable1 = npc.EquipItem("head", "models/workshop_partner/weapons/c_models/c_tw_eagle/c_tw_eagle.mdl");
		npc.m_iWearable2 = npc.EquipItem("head", "models/workshop/player/items/sniper/xms_sniper_commandobackpack/xms_sniper_commandobackpack.mdl");
		npc.m_iWearable3 = npc.EquipItem("head", "models/workshop/player/items/heavy/dec18_paka_parka/dec18_paka_parka.mdl");
		npc.m_iWearable4 = npc.EquipItem("head", "models/workshop/player/items/heavy/sum23_hog_heels/sum23_hog_heels.mdl");
		npc.m_iWearable5 = npc.EquipItem("head", "models/workshop/player/items/heavy/spr17_warhood/spr17_warhood.mdl");
		
		SetEntProp(npc.m_iWearable1, Prop_Send, "m_nSkin", skin);
		SetEntProp(npc.m_iWearable2, Prop_Send, "m_nSkin", skin);
		SetEntProp(npc.m_iWearable3, Prop_Send, "m_nSkin", skin);
		SetEntProp(npc.m_iWearable4, Prop_Send, "m_nSkin", skin);
		SetEntProp(npc.m_iWearable5, Prop_Send, "m_nSkin", skin);

		return npc;
	}
}

public void WinterArcticMage_ClotThink(int iNPC)
{
	WinterArcticMage npc = view_as<WinterArcticMage>(iNPC);
	if(npc.m_flNextDelayTime > GetGameTime(npc.index))
	{
		return;
	}
	npc.m_flNextDelayTime = GetGameTime(npc.index) + DEFAULT_UPDATE_DELAY_FLOAT;
	npc.Update();
	

	if(npc.m_blPlayHurtAnimation)
	{
		npc.AddGesture("ACT_MP_GESTURE_FLINCH_CHEST", false);
		npc.m_blPlayHurtAnimation = false;
		npc.PlayHurtSound();	
		if(!VausMagicaShieldLogicEnabled(npc.index))
			VausMagicaGiveShield(npc.index, 1); 
	}
	
	if(npc.m_flNextThinkTime > GetGameTime(npc.index))
	{
		return;
	}
	npc.m_flNextThinkTime = GetGameTime(npc.index) + 0.1;

	if(npc.m_flGetClosestTargetTime < GetGameTime(npc.index))
	{
		npc.m_iTarget = GetClosestTarget(npc.index);
		npc.m_flGetClosestTargetTime = GetGameTime(npc.index) + GetRandomRetargetTime();
	}
	
	if(IsValidEnemy(npc.index, npc.m_iTarget))
	{
		float vecTarget[3]; vecTarget = WorldSpaceCenterOld(npc.m_iTarget);
	
		float flDistanceToTarget = GetVectorDistance(vecTarget, WorldSpaceCenterOld(npc.index), true);
		if(flDistanceToTarget < npc.GetLeadRadius()) 
		{
			float vPredictedPos[3];
			vPredictedPos = PredictSubjectPositionOld(npc, npc.m_iTarget);
			NPC_SetGoalVector(npc.index, vPredictedPos);
		}
		else 
		{
			NPC_SetGoalEntity(npc.index, npc.m_iTarget);
		}
		WinterArcticMageSelfDefense(npc,GetGameTime(npc.index), npc.m_iTarget, flDistanceToTarget); 
	}
	else
	{
		npc.m_flGetClosestTargetTime = 0.0;
		npc.m_iTarget = GetClosestTarget(npc.index);
	}
	npc.PlayIdleAlertSound();
}

public Action WinterArcticMage_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	WinterArcticMage npc = view_as<WinterArcticMage>(victim);
		
	if(attacker <= 0)
		return Plugin_Continue;
		
	if (npc.m_flHeadshotCooldown < GetGameTime(npc.index))
	{
		npc.m_flHeadshotCooldown = GetGameTime(npc.index) + DEFAULT_HURTDELAY;
		npc.m_blPlayHurtAnimation = true;
	}
	//grand 1 shield every time he is hurt if the CD is up.

	WinterArcticMageHealRandomAlly(victim, damage);
	
	return Plugin_Changed;
}

void WinterArcticMageHealRandomAlly(int victim, float damage)
{
	RajulHealAlly[victim] += (damage * 0.15);
	if(RajulHealAllyCooldownAntiSpam[victim] < GetGameTime())
	{
		RajulHealAllyDone[victim] = 0;
		RajulHealAllyCooldownAntiSpam[victim] = GetGameTime() + 0.5;
		int TeamNum = GetEntProp(victim, Prop_Send, "m_iTeamNum");
		SetEntProp(victim, Prop_Send, "m_iTeamNum", 4);
		Explode_Logic_Custom(0.0,
		victim,
		victim,
		-1,
		_,
		150.0,
		_,
		_,
		true,
		99,
		false,
		_,
		WinterArcticMageAllyHeal);
		SetEntProp(victim, Prop_Send, "m_iTeamNum", TeamNum);	
		RajulHealAlly[victim] = 0.0;
	}
}

public void WinterArcticMage_NPCDeath(int entity)
{
	WinterArcticMage npc = view_as<WinterArcticMage>(entity);
	if(!npc.m_bGib)
	{
		npc.PlayDeathSound();	
	}
		
	if(IsValidEntity(npc.m_iWearable5))
		RemoveEntity(npc.m_iWearable5);
	if(IsValidEntity(npc.m_iWearable4))
		RemoveEntity(npc.m_iWearable4);
	if(IsValidEntity(npc.m_iWearable3))
		RemoveEntity(npc.m_iWearable3);
	if(IsValidEntity(npc.m_iWearable2))
		RemoveEntity(npc.m_iWearable2);
	if(IsValidEntity(npc.m_iWearable1))
		RemoveEntity(npc.m_iWearable1);

}

void WinterArcticMageSelfDefense(WinterArcticMage npc, float gameTime, int target, float distance)
{
	if(npc.m_flAttackHappens)
	{
		if(npc.m_flAttackHappens < gameTime)
		{
			npc.m_flAttackHappens = 0.0;
			
			Handle swingTrace;
			npc.FaceTowards(WorldSpaceCenterOld(npc.m_iTarget), 15000.0);
			if(npc.DoSwingTrace(swingTrace, npc.m_iTarget, _, _, _, 1)) //Big range, but dont ignore buildings if somehow this doesnt count as a raid to be sure.
			{
							
				target = TR_GetEntityIndex(swingTrace);	
				
				float vecHit[3];
				TR_GetEndPosition(vecHit, swingTrace);
				
				if(IsValidEnemy(npc.index, target))
				{
					float damageDealt = 125.0;
					if(ShouldNpcDealBonusDamage(target))
						damageDealt *= 3.5;


					SDKHooks_TakeDamage(target, npc.index, npc.index, damageDealt, DMG_CLUB, -1, _, vecHit);
					Sakratan_AddNeuralDamage(target, npc.index, 40);

					// Hit sound
					npc.PlayMeleeHitSound();
				} 
			}
			delete swingTrace;
		}
	}

	if(gameTime > npc.m_flNextMeleeAttack)
	{
		if(distance < (GIANT_ENEMY_MELEE_RANGE_FLOAT_SQUARED))
		{
			int Enemy_I_See;
								
			Enemy_I_See = Can_I_See_Enemy(npc.index, npc.m_iTarget);
					
			if(IsValidEnemy(npc.index, Enemy_I_See))
			{
				npc.m_iTarget = Enemy_I_See;
				npc.PlayMeleeSound();
				npc.AddGesture("ACT_MP_ATTACK_STAND_MELEE_ALLCLASS");
						
				npc.m_flAttackHappens = gameTime + 0.25;
				npc.m_flDoingAnimation = gameTime + 0.25;
				npc.m_flNextMeleeAttack = gameTime + 1.0;
			}
		}
	}
}


void WinterArcticMageAllyHeal(int entity, int victim, float damage, int weapon)
{
	if(entity == victim)
		return;

	if(b_IsAlliedNpc[entity])
	{
		if (RajulHealAllyDone[entity] <= 2 && b_IsAlliedNpc[victim])
		{
			RajulHealAllyDone[entity] += 1;
			WinterArcticMageAllyHealInternal(entity, victim, RajulHealAlly[entity]);
		}
	}
	else
	{
		if (RajulHealAllyDone[entity] <= 2 && !b_IsAlliedNpc[victim] && !i_IsABuilding[victim] && victim > MaxClients && i_NpcInternalId[victim] != INTERITUS_WINTER_ARCTIC_MAGE)
		{
			RajulHealAllyDone[entity] += 1;
			WinterArcticMageAllyHealInternal(entity, victim, RajulHealAlly[entity]);
		}
	}
}

void WinterArcticMageAllyHealInternal(int entity, int victim, float heal)
{
	HealEntityGlobal(entity, victim, heal, 99.0,_,_);
	int flHealth = GetEntProp(victim, Prop_Data, "m_iHealth");
	int flMaxHealth = GetEntProp(victim, Prop_Data, "m_iMaxHealth");

	if(b_thisNpcIsABoss[victim] || b_thisNpcIsARaid[victim])
	{
		//bosses and raids need much more overheal to get this insanely strong buff!
		flMaxHealth = RoundToCeil(float(flMaxHealth) * 1.5);
	}
	else
	{
		flMaxHealth = RoundToCeil(float(flMaxHealth) * 1.15);
	}
	//silence disables this superbuff accuring.
	if(!NpcStats_IsEnemySilenced(entity) && !NpcStats_IsEnemySilenced(victim))
	{
		if(flHealth > flMaxHealth)
		{
			//super power!
			f_BuffBannerNpcBuff[victim] = FAR_FUTURE;
			f_BattilonsNpcBuff[victim] = FAR_FUTURE;
		}
	}

	float ProjLoc[3];
	GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", ProjLoc);
	ProjLoc[2] += 100.0;
	TE_Particle("healthgained_blu", ProjLoc, NULL_VECTOR, NULL_VECTOR, _, _, _, _, _, _, _, _, _, _, 0.0);
	VausMagicaGiveShield(victim, 1);
	//yippie reuse
}