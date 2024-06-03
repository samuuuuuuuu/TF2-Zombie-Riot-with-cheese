#pragma semicolon 1
#pragma newdecls required

enum struct MusicEnum
{
	char Sound[PLATFORM_MAX_PATH];
	int Duration;
	float Volume;
	bool Custom;

	void SetupEnum(KeyValues kv)
	{
		kv.GetString("sound", this.Sound, PLATFORM_MAX_PATH);
		this.Duration = kv.GetNum("duration");
		this.Volume = kv.GetFloat("volume", 1.0);
		int custom = kv.GetNum("download");
		this.Custom = view_as<bool>(custom);
		
		if(this.Sound[0])
		{
			if(this.Custom)
			{
				PrecacheSoundCustom(this.Sound, _, custom);
			}
			else
			{
				PrecacheSound(this.Sound);
			}
		}
	}
}

static int CurrentZone[MAXTF2PLAYERS] = {-1, ...};
static int NextZone[MAXTF2PLAYERS] = {-1, ...};
static int NextSoundIn[MAXTF2PLAYERS];
static float FadingOut[MAXTF2PLAYERS];
static float FadingIn[MAXTF2PLAYERS];
static char OverrideSong[MAXTF2PLAYERS][PLATFORM_MAX_PATH];
static int OverrideTime[MAXTF2PLAYERS];
static bool OverrideCustom[MAXTF2PLAYERS];
static float OverrideVolume[MAXTF2PLAYERS];

void Music_ZoneEnter(int client, int entity)
{
	// TODO: Set all oberservers too
	static char newSong[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_nMusicFile", newSong, sizeof(newSong));
	if(newSong[0])
		NextZone[client] = EntIndexToEntRef(entity);
}

void Music_ClientDisconnect(int client)
{
	CurrentZone[client] = -1;
	NextZone[client] = -1;
	OverrideSong[client][0] = 0;
}

void Music_SetOverride(int client, const char[] file = "", int time = 0, bool custom = false, float volume = 1.0)
{
	if(OverrideSong[client][0])
	{
		StopSound(client, SNDCHAN_STATIC, OverrideSong[client]);
		StopSound(client, SNDCHAN_STATIC, OverrideSong[client]);
	}

	strcopy(OverrideSong[client], sizeof(OverrideSong[]), file);
	OverrideTime[client] = time;
	OverrideCustom[client] = custom;
	OverrideVolume[client] = volume;
}

void Music_PlayerRunCmd(int client)
{
	//Do not play anything if the client has no sound.
	if(f_ClientMusicVolume[client] < 0.05)
		return;

	if(CurrentZone[client] != -1 || NextZone[client] != -1 || OverrideSong[client][0])
	{
		static char oldSong[PLATFORM_MAX_PATH], newSong[PLATFORM_MAX_PATH];
		int time = GetTime();

		if(FadingOut[client])
		{
			if(CurrentZone[client] != -1)
			{
				int entity = EntRefToEntIndex(CurrentZone[client]);
				if(entity != -1)
				{
					GetEntPropString(entity, Prop_Data, "m_nMusicFile", oldSong, sizeof(oldSong));

					float vol = GetEntPropFloat(entity, Prop_Data, "m_fMusicVolume") - ((GetGameTime() - FadingOut[client]) / 2.0);
					if(vol > 0.0)
					{
						EmitMusicToClient(client, oldSong, view_as<bool>(GetEntProp(entity, Prop_Data, "m_bMusicCustom")), vol, SND_CHANGEVOL);
						return;
					}

					StopSound(client, SNDCHAN_STATIC, oldSong);
					StopSound(client, SNDCHAN_STATIC, oldSong);
				}
			
				CurrentZone[client] = -1;
			}
			
			FadingOut[client] = 0.0;
			//PrintToChat(client, "DEBUG: Fade Out Done");
		}
		else if(FadingIn[client])
		{
			if(CurrentZone[client] != -1)
			{
				int entity = EntRefToEntIndex(CurrentZone[client]);
				if(entity != -1)
				{
					GetEntPropString(entity, Prop_Data, "m_nMusicFile", newSong, sizeof(newSong));
					float volume = GetEntPropFloat(entity, Prop_Data, "m_fMusicVolume");

					float vol = ((GetGameTime() - FadingIn[client]) / 2.0);
					if(vol < volume)
					{
						EmitMusicToClient(client, newSong, view_as<bool>(GetEntProp(entity, Prop_Data, "m_bMusicCustom")), vol, SND_CHANGEVOL);
						return;
					}

					EmitMusicToClient(client, newSong, view_as<bool>(GetEntProp(entity, Prop_Data, "m_bMusicCustom")), volume, SND_CHANGEVOL);
				}
			}
			
			FadingIn[client] = 0.0;
			//PrintToChat(client, "DEBUG: Fade In Done");
		}
		else if(NextZone[client] != -1 && (CurrentZone[client] != -1 || !OverrideSong[client][0]))
		{
			if(CurrentZone[client] == -1)
			{
				int entity = EntRefToEntIndex(NextZone[client]);
				if(entity != -1)
				{
					// Start fading in our new
					CurrentZone[client] = NextZone[client];
					FadingIn[client] = GetGameTime();
					NextSoundIn[client] = time + GetEntProp(entity, Prop_Data, "m_iMusicDuration");
				}

				NextZone[client] = -1;
				//PrintToChat(client, "DEBUG: Start Fade In");
			}
			else
			{
				int entity = EntRefToEntIndex(CurrentZone[client]);
				if(entity != -1)
					GetEntPropString(entity, Prop_Data, "m_nMusicFile", oldSong, sizeof(oldSong));
				
				if(OverrideSong[client][0])
				{
					// Start fading out our current
					FadingOut[client] = GetGameTime();
					NextSoundIn[client] = 0;
					//PrintToChat(client, "DEBUG: Start Fade Out Override");
				}
				else
				{
					entity = EntRefToEntIndex(NextZone[client]);
					if(entity != -1)
						GetEntPropString(entity, Prop_Data, "m_nMusicFile", newSong, sizeof(newSong));
					
					if(StrEqual(oldSong, newSong))
					{
						// Same music, don't start fading
						NextZone[client] = -1;
						//PrintToChat(client, "DEBUG: Music Same");
					}
					else
					{
						// Start fading out our current
						FadingOut[client] = GetGameTime();
						//PrintToChat(client, "DEBUG: Start Fade Out");
					}
				}
			}
		}
		else if(NextSoundIn[client] < time)
		{
			NextSoundIn[client] = 0;

			if(OverrideSong[client][0])
			{
				EmitMusicToClient(client, OverrideSong[client], OverrideCustom[client], OverrideVolume[client]);
				NextSoundIn[client] = time + OverrideTime[client];
				CurrentZone[client] = -1;
				//PrintToChat(client, "DEBUG: Override Start");
			}
			else if(CurrentZone[client] != -1)
			{
				int entity = EntRefToEntIndex(CurrentZone[client]);
				if(entity != -1)
				{
					GetEntPropString(entity, Prop_Data, "m_nMusicFile", newSong, sizeof(newSong));
					if(newSong[0])
					{
						EmitMusicToClient(client, newSong, view_as<bool>(GetEntProp(entity, Prop_Data, "m_bMusicCustom")), GetEntPropFloat(entity, Prop_Data, "m_fMusicVolume"));
						NextSoundIn[client] = time + GetEntProp(entity, Prop_Data, "m_iMusicDuration");
					}
				}

				//PrintToChat(client, "DEBUG: Current Start");
			}
		}
	}
}

void EmitMusicToClient(int client, const char[] sound, bool custom, float volume, int flags = SND_NOFLAGS)
{
	if(custom)
	{
		EmitCustomToClient(client, sound, client, SNDCHAN_STATIC, SNDLEVEL_NONE, flags, volume);
	}
	else
	{
		EmitSoundToClient(client, sound, client, SNDCHAN_STATIC, SNDLEVEL_NONE, flags, volume);
	}
}