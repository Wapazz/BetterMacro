local _, ns = ...
local C = ns.Catalog

-- Macros adapted from classicwowforever.com/fr/macros (licence CC BY 4.0,
-- https://creativecommons.org/licenses/by/4.0/), "whole class" sections.
-- Changes: spell and item names replaced by IDs so they work in every client
-- language, wording of names is ours, chat announcements reworded.
--
-- {sID|Name} = spell, {iID|Name} = item. ID 0 = not known for Classic: the
-- English name is used as is (works on English clients only).
-- Every ID still needs checking in game on WoW Forever.
C.SOURCE = "classicwowforever.com (CC BY 4.0)"

local function add(id, class, role, tags, text, faction)
    C.list[#C.list + 1] = {
        id = id, class = class, role = role, tags = tags, text = text,
        faction = faction, source = C.SOURCE,
    }
end

------------------------------------------------------------------ Druid
add("CW_DRU_REBIRTH", "DRUID", "heal", { "group" }, [==[
#showtooltip
/cast [@mouseover,help,dead][help,dead][] {s20484|Rebirth}]==])
add("CW_DRU_DECURSE", "DRUID", "utility", { "group" }, [==[
#showtooltip
/cast [@mouseover,help,nodead][help,nodead][@player] {s2782|Remove Curse}]==])
add("CW_DRU_POISON", "DRUID", "utility", { "group" }, [==[
#showtooltip
/cancelform
/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] {s2893|Abolish Poison}; [@mouseover,help,nodead][help,nodead][@player] {s8946|Cure Poison}]==])
add("CW_DRU_REZ", "DRUID", "heal", { "group" }, [==[
#showtooltip
/cast [@mouseover,help,dead,combat][help,dead,combat] {s20484|Rebirth}
/cast [@mouseover,help,dead,nocombat][help,dead,nocombat] {s0|Revive}]==])
add("CW_DRU_INNERVATE", "DRUID", "heal", { "group" }, [==[
#showtooltip
/cancelform
/cast [@mouseover,help,nodead][help,nodead][@player] {s29166|Innervate}]==])
add("CW_DRU_MOTW", "DRUID", "utility", { "group", "solo" }, [==[
#showtooltip
/cancelform
/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] {s467|Thorns}; [@mouseover,help,nodead][help,nodead][@player] {s1126|Mark of the Wild}]==])
add("CW_DRU_FORMS", "DRUID", "tank", { "solo", "group" }, [==[
#showtooltip
/dismount
/cast [mod:shift] {s5487|Bear Form}; {s768|Cat Form}]==])
add("CW_DRU_TRAVEL", "DRUID", "utility", { "solo" }, [==[
#showtooltip
/dismount
/cast [swimming] {s1066|Aquatic Form}; [outdoors] {s783|Travel Form}; {s768|Cat Form}]==])
add("CW_DRU_HT", "DRUID", "heal", { "group", "solo" }, [==[
#showtooltip
/cancelform
/cast [mod:shift,@mouseover,help,nodead][mod:shift,@player] {s8936|Regrowth}; [@mouseover,help,nodead][@player] {s5185|Healing Touch}]==])
add("CW_DRU_RESET", "DRUID", "utility", { "solo", "pvp" }, [==[
/stopcasting
/cancelform
/dismount]==])
add("CW_DRU_BARK", "DRUID", "utility", { "solo", "pvp" }, [==[
#showtooltip
/cast [mod:shift] {s16689|Nature's Grasp}; {s22812|Barkskin}]==])

------------------------------------------------------------------ Hunter
add("CW_HUN_MEND", "HUNTER", "utility", { "pet" }, [==[
#showtooltip
/cast [@pet,exists,nodead] {s136|Mend Pet}]==])
add("CW_HUN_PET_MO", "HUNTER", "dps", { "pet", "group" }, [==[
/petattack [@mouseover,harm,nodead][]]==])
add("CW_HUN_PET_CTRL", "HUNTER", "utility", { "pet" }, [==[
/petattack [nomod:shift,harm,nodead]
/petpassive [mod:shift]
/petfollow [mod:shift]]==])
add("CW_HUN_PET_ALL", "HUNTER", "utility", { "pet" }, [==[
#showtooltip
/cast [@pet,dead][mod:shift] {s982|Revive Pet}; [nopet] {s883|Call Pet}; {s136|Mend Pet}]==])
add("CW_HUN_FEED", "HUNTER", "utility", { "pet" }, [==[
#showtooltip
/cast [pet,nocombat] {s6991|Feed Pet}
/use [pet,nocombat] {i769|Chunk of Boar Meat}]==])
add("CW_HUN_HAWK", "HUNTER", "dps", { "solo", "group" }, [==[
#showtooltip
/cancelaura {s5118|Aspect of the Cheetah}
/cast !{s13165|Aspect of the Hawk}]==])
add("CW_HUN_CHEETAH", "HUNTER", "utility", { "solo", "group" }, [==[
#showtooltip
/cast [button:2] !{s13159|Aspect of the Pack}; !{s5118|Aspect of the Cheetah}]==])
add("CW_HUN_TRACK", "HUNTER", "utility", { "solo" }, [==[
#showtooltip
/cast [mod:shift] {s1494|Track Beasts}; [mod:ctrl] {s19884|Track Undead}; [mod:alt] {s19885|Track Hidden}; {s19883|Track Humanoids}]==])
add("CW_HUN_FD", "HUNTER", "utility", { "group", "pvp" }, [==[
#showtooltip
/petpassive
/petfollow
/stopattack
/stopcasting
/cast [combat] {s5384|Feign Death}]==])
add("CW_HUN_UNASPECT", "HUNTER", "utility", { "solo", "group" }, [==[
/cancelaura {s5118|Aspect of the Cheetah}
/cancelaura {s13159|Aspect of the Pack}]==])
add("CW_HUN_EAGLE", "HUNTER", "utility", { "solo", "pvp" }, [==[
#showtooltip
/cast !{s6197|Eagle Eye}]==])

------------------------------------------------------------------ Mage
add("CW_MAG_CS", "MAGE", "utility", { "group", "pvp" }, [==[
#showtooltip
/stopcasting
/cast {s2139|Counterspell}]==])
add("CW_MAG_POLY_MO", "MAGE", "utility", { "group", "pvp" }, [==[
#showtooltip
/cast [@mouseover,harm,nodead][] {s118|Polymorph}]==])
add("CW_MAG_AI_ALT", "MAGE", "utility", { "group" }, [==[
#showtooltip
/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] {s1459|Arcane Intellect}]==])
add("CW_MAG_DAMPEN", "MAGE", "utility", { "group" }, [==[
#showtooltip
/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] {s1008|Amplify Magic}; [@mouseover,help,nodead][help,nodead][@player] {s604|Dampen Magic}]==])
add("CW_MAG_DECURSE", "MAGE", "utility", { "group" }, [==[
#showtooltip
/cast [mod:shift,@player][@mouseover,help,nodead][help,nodead][@player] {s475|Remove Lesser Curse}]==])
add("CW_MAG_CONJURE", "MAGE", "utility", { "solo", "group" }, [==[
#showtooltip
/cast [mod:shift] {s587|Conjure Food}; {s5504|Conjure Water}]==])
add("CW_MAG_GEM", "MAGE", "dps", { "group" }, [==[
#showtooltip
/use {i8008|Mana Ruby}
/use {i8007|Mana Citrine}
/use {i5513|Mana Jade}
/use {i5514|Mana Agate}]==])
add("CW_MAG_ARMOR", "MAGE", "utility", { "solo", "group" }, [==[
#showtooltip
/cast [mod:shift] {s6117|Mage Armor}; [mod:ctrl] {s168|Frost Armor}; {s7302|Ice Armor}]==])
add("CW_MAG_TP_A", "MAGE", "utility", { "solo" }, [==[
#showtooltip
/cast [mod:shift] {s3562|Teleport: Ironforge}; [mod:ctrl] {s3565|Teleport: Darnassus}; [mod:alt] {s0|Teleport: Dalaran}; {s3561|Teleport: Stormwind}]==], "Alliance")
add("CW_MAG_TP_H", "MAGE", "utility", { "solo" }, [==[
#showtooltip
/cast [mod:shift] {s3563|Teleport: Undercity}; [mod:ctrl] {s3566|Teleport: Thunder Bluff}; [mod:alt] {s0|Teleport: Dalaran}; {s3567|Teleport: Orgrimmar}]==], "Horde")
add("CW_MAG_PORTAL_A", "MAGE", "utility", { "group" }, [==[
#showtooltip
/cast [mod:shift] {s11416|Portal: Ironforge}; [mod:ctrl] {s11419|Portal: Darnassus}; {s10059|Portal: Stormwind}]==], "Alliance")
add("CW_MAG_PORTAL_H", "MAGE", "utility", { "group" }, [==[
#showtooltip
/cast [mod:shift] {s11418|Portal: Undercity}; [mod:ctrl] {s11420|Portal: Thunder Bluff}; {s11417|Portal: Orgrimmar}]==], "Horde")
add("CW_MAG_SLOWFALL", "MAGE", "utility", { "solo" }, [==[
#showtooltip
/dismount [nomod:shift]
/cancelaura [mod:shift] {s130|Slow Fall}
/cast [nomod:shift,@player] {s130|Slow Fall}]==])
add("CW_MAG_BRILLIANCE", "MAGE", "utility", { "group" }, [==[
#showtooltip
/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] {s23028|Arcane Brilliance}; [@mouseover,help,nodead][help,nodead][@player] {s1459|Arcane Intellect}]==])

------------------------------------------------------------------ Paladin
add("CW_PAL_HOLYSTRIKE", "PALADIN", "dps", { "solo" }, [==[
#showtooltip
/startattack
/cast {s0|Holy Strike}]==])
add("CW_PAL_BOP", "PALADIN", "utility", { "group" }, [==[
#showtooltip
/cast [mod:alt] {s498|Divine Protection}; [@mouseover,help,nodead][help,nodead][@targettarget,help,nodead] {s1022|Blessing of Protection}]==])
add("CW_PAL_BLESSINGS", "PALADIN", "utility", { "group" }, [==[
#showtooltip
/cast [mod:shift,@mouseover,help,nodead][mod:shift] {s19742|Blessing of Wisdom}; [mod:ctrl,@mouseover,help,nodead][mod:ctrl] {s20217|Blessing of Kings}; [@mouseover,help,nodead][] {s19740|Blessing of Might}]==])
add("CW_PAL_AURAS", "PALADIN", "utility", { "group", "solo" }, [==[
#showtooltip
/cast [mod:shift] {s19746|Concentration Aura}; [mod:ctrl] {s7294|Retribution Aura}; {s465|Devotion Aura}]==])
add("CW_PAL_RESIST", "PALADIN", "utility", { "group" }, [==[
#showtooltip
/cast [mod:shift] {s19888|Frost Resistance Aura}; [mod:ctrl] {s19876|Shadow Resistance Aura}; {s19891|Fire Resistance Aura}]==])
add("CW_PAL_LOH", "PALADIN", "heal", { "group", "solo" }, [==[
#showtooltip
/cast [@mouseover,help,nodead][help,nodead][@player] {s633|Lay on Hands}]==])
add("CW_PAL_BUBBLE", "PALADIN", "utility", { "solo", "pvp" }, [==[
#showtooltip
/cancelaura {s642|Divine Shield}
/cancelaura {s498|Divine Protection}
/cancelaura {s1022|Blessing of Protection}
/cast {s642|Divine Shield}]==])
add("CW_PAL_REZ", "PALADIN", "heal", { "group" }, [==[
#showtooltip
/cast [@mouseover,help,dead][help,dead] {s7328|Redemption}]==])
add("CW_PAL_EXORCISM", "PALADIN", "dps", { "solo", "group" }, [==[
#showtooltip
/cast [mod:shift,harm,nodead] {s2878|Turn Undead}; [harm,nodead] {s879|Exorcism}]==])

------------------------------------------------------------------ Priest
add("CW_PRI_DISPEL", "PRIEST", "utility", { "group" }, [==[
#showtooltip
/cast [@mouseover,exists,nodead][] {s527|Dispel Magic}]==])
add("CW_PRI_FORT", "PRIEST", "utility", { "group", "solo" }, [==[
#showtooltip
/cast [@mouseover,help,nodead][help,nodead][@player] {s1243|Power Word: Fortitude}]==])
add("CW_PRI_FEARWARD", "PRIEST", "utility", { "group" }, [==[
#showtooltip
/cast [@mouseover,help,nodead][help,nodead][@player] {s6346|Fear Ward}]==])
add("CW_PRI_SHACKLE_MO", "PRIEST", "utility", { "group" }, [==[
#showtooltip
/cast [@mouseover,harm,nodead][harm,nodead] {s9484|Shackle Undead}]==])
add("CW_PRI_WAND", "PRIEST", "dps", { "solo", "group" }, [==[
#showtooltip
/cast !{s5019|Shoot}]==])
add("CW_PRI_REZ", "PRIEST", "heal", { "group" }, [==[
#showtooltip
/cast [@mouseover,help,dead][help,dead] {s2006|Resurrection}]==])
add("CW_PRI_LEVITATE", "PRIEST", "utility", { "solo" }, [==[
#showtooltip
/dismount
/cancelaura [mod:shift] {s1706|Levitate}
/cast [nomod] {s1706|Levitate}]==])
add("CW_PRI_BUFFS", "PRIEST", "utility", { "solo" }, [==[
#showtooltip
/castsequence [@player] reset=15 {s588|Inner Fire}, {s1243|Power Word: Fortitude}, {s14752|Divine Spirit}]==])
add("CW_PRI_HEALSMITE", "PRIEST", "heal", { "solo", "group" }, [==[
#showtooltip
/cast [@mouseover,help,nodead] {s2050|Lesser Heal}; [harm,nodead] {s585|Smite}; [help,nodead][@player] {s2050|Lesser Heal}]==])

------------------------------------------------------------------ Rogue
add("CW_ROG_KICK_MO", "ROGUE", "utility", { "group", "pvp" }, [==[
#showtooltip
/cast [@mouseover,harm,nodead][] {s1766|Kick}]==])
add("CW_ROG_SAP_MO", "ROGUE", "utility", { "group", "pvp" }, [==[
#showtooltip
/cast [@mouseover,harm,nodead][] {s6770|Sap}]==])
add("CW_ROG_STEALTH", "ROGUE", "utility", { "solo", "pvp" }, [==[
#showtooltip
/dismount
/cast [nostealth,nocombat] {s1784|Stealth}]==])
add("CW_ROG_PICK_MO", "ROGUE", "utility", { "solo" }, [==[
#showtooltip
/cast [@mouseover,harm,nodead][] {s921|Pick Pocket}]==])
add("CW_ROG_OPENERS", "ROGUE", "dps", { "solo", "pvp" }, [==[
#showtooltip
/cast [stealth] {s921|Pick Pocket}
/cast [nostealth] {s1784|Stealth}; [mod:shift] {s703|Garrote}; [mod:ctrl] {s8676|Ambush}; {s1833|Cheap Shot}]==])
add("CW_ROG_ESCAPE", "ROGUE", "utility", { "solo", "pvp" }, [==[
#showtooltip
/cast {s5277|Evasion}
/cast {s2983|Sprint}]==])
add("CW_ROG_TRINKETS", "ROGUE", "dps", { "group", "pvp" }, [==[
#showtooltip
/use 13
/use 14]==])
add("CW_ROG_POISON", "ROGUE", "utility", { "solo", "group" }, [==[
#showtooltip
/use [mod:shift] {i2892|Deadly Poison}; {i6947|Instant Poison}
/use [mod:alt] 17; 16
/click StaticPopup1Button1]==])
add("CW_ROG_STONE", "ROGUE", "utility", { "solo", "group" }, [==[
#showtooltip
/use [mod:shift] {i3241|Heavy Weightstone}; {i2871|Heavy Sharpening Stone}
/use [mod:alt] 17; 16
/click StaticPopup1Button1]==])
add("CW_ROG_VANISH", "ROGUE", "utility", { "solo", "pvp" }, [==[
#showtooltip
/stopattack [combat]
/cast [nocombat] !{s1784|Stealth}; {s1856|Vanish}]==])
add("CW_ROG_SHANK", "ROGUE", "dps", { "solo" }, [==[
#showtooltip
/startattack
/cast {s0|Shank}]==])

------------------------------------------------------------------ Shaman
add("CW_SHA_ES_MO", "SHAMAN", "utility", { "group", "pvp" }, [==[
#showtooltip
/stopcasting
/cast [@mouseover,harm,nodead][] {s8042|Earth Shock}]==])
add("CW_SHA_TOTEMS", "SHAMAN", "utility", { "group", "solo" }, [==[
#showtooltip
/cast [mod:ctrl] {s0|Totemic Call}; [mod:shift] {s0|Totemic Recall}; {s0|Call of the Elements}]==])
add("CW_SHA_TOTEM_SETS", "SHAMAN", "utility", { "group" }, [==[
#showtooltip
/cast [mod:ctrl] {s0|Call of the Ancestors}; [mod:alt] {s0|Call of the Spirits}; [mod:shift] {s0|Totemic Recall}; {s0|Call of the Elements}]==])
add("CW_SHA_SHIELDS", "SHAMAN", "utility", { "solo", "group" }, [==[
#showtooltip
/cast [mod:shift] {s0|Water Shield}; {s324|Lightning Shield}]==])
add("CW_SHA_WOLF", "SHAMAN", "utility", { "solo" }, [==[
#showtooltip
/cast {s2645|Ghost Wolf}]==])
add("CW_SHA_PURGE_MO", "SHAMAN", "utility", { "group", "pvp" }, [==[
#showtooltip
/cast [@mouseover,harm,nodead][] {s370|Purge}]==])
add("CW_SHA_SHOCKS", "SHAMAN", "dps", { "solo", "group" }, [==[
#showtooltip
/cast [mod:shift] {s8050|Flame Shock}; [mod:ctrl] {s8056|Frost Shock}; {s8042|Earth Shock}]==])
add("CW_SHA_CURES", "SHAMAN", "utility", { "group" }, [==[
#showtooltip
/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] {s2870|Cure Disease}; [@mouseover,help,nodead][help,nodead][@player] {s526|Cure Poison}]==])
add("CW_SHA_ANKH", "SHAMAN", "utility", { "group" }, [==[
#showtooltip {s20608|Reincarnation}]==])
add("CW_SHA_SELFHEAL", "SHAMAN", "heal", { "solo" }, [==[
#showtooltip
/cast [mod:shift,@player] {s8004|Lesser Healing Wave}; [@player] {s331|Healing Wave}]==])
add("CW_SHA_WATER", "SHAMAN", "utility", { "solo", "group" }, [==[
#showtooltip
/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] {s131|Water Breathing}; [@mouseover,help,nodead][help,nodead][@player] {s546|Water Walking}]==])

------------------------------------------------------------------ Warlock
add("CW_WLK_FEAR_MO", "WARLOCK", "utility", { "group", "pvp" }, [==[
#showtooltip
/cast [@mouseover,harm,nodead][] {s5782|Fear}]==])
add("CW_WLK_RECALL", "WARLOCK", "utility", { "pet" }, [==[
/petpassive
/petfollow]==])
add("CW_WLK_SUMMON", "WARLOCK", "utility", { "pet" }, [==[
#showtooltip
/cast [mod:shift] {s688|Summon Imp}; [mod:ctrl] {s712|Summon Succubus}; [mod:alt] {s691|Summon Felhunter}; {s697|Summon Voidwalker}]==])
add("CW_WLK_CURSES", "WARLOCK", "dps", { "group", "pvp" }, [==[
#showtooltip
/cast [mod:shift,@mouseover,harm,nodead][mod:shift] {s702|Curse of Weakness}; [mod:ctrl,@mouseover,harm,nodead][mod:ctrl] {s704|Curse of Recklessness}; [mod:alt] {s1714|Curse of Tongues}; [@mouseover,harm,nodead][] {s1490|Curse of the Elements}]==])
add("CW_WLK_LEVEL_SEQ", "WARLOCK", "dps", { "solo", "pet" }, [==[
#showtooltip
/petattack [harm,nodead]
/castsequence reset=target {s348|Immolate}, {s980|Curse of Agony}, {s172|Corruption}, !{s5019|Shoot}]==])
add("CW_WLK_WAND", "WARLOCK", "dps", { "solo", "group" }, [==[
#showtooltip 18
/cast !{s5019|Shoot}]==])
add("CW_WLK_HEALTHSTONE", "WARLOCK", "utility", { "solo", "group", "pvp" }, [==[
#showtooltip
/use {i9421|Major Healthstone}
/use {i5510|Greater Healthstone}
/use {i5509|Healthstone}
/use {i5511|Lesser Healthstone}
/use {i5512|Minor Healthstone}
/cast [mod:shift] {s689|Drain Life}]==])
add("CW_WLK_SOULSTONE", "WARLOCK", "utility", { "group" }, [==[
#showtooltip
/use [@mouseover,help,nodead][] {i16896|Major Soulstone}
/use [@mouseover,help,nodead][] {i16895|Greater Soulstone}
/use [@mouseover,help,nodead][] {i16893|Soulstone}
/use [@mouseover,help,nodead][] {i16892|Lesser Soulstone}
/use [@mouseover,help,nodead][] {i5232|Minor Soulstone}]==])
add("CW_WLK_STONES", "WARLOCK", "utility", { "solo", "group" }, [==[
#showtooltip
/cast [mod:shift] {s693|Create Soulstone}; [mod:ctrl] {s2362|Create Spellstone}; [mod:alt] {s6366|Create Firestone}; {s6201|Create Healthstone}]==])
add("CW_WLK_SUMMONING", "WARLOCK", "utility", { "group" }, [==[
#showtooltip
/party Summoning %t, click the portal to help!
/cast {s698|Ritual of Summoning}]==])
add("CW_WLK_ARMOR", "WARLOCK", "utility", { "solo", "group" }, [==[
#showtooltip
/cast [mod:shift] {s6229|Shadow Ward}; {s706|Demon Armor}]==])

------------------------------------------------------------------ Warrior
add("CW_WAR_CHARGE", "WARRIOR", "dps", { "solo" }, [==[
#showtooltip
/dismount
/startattack
/cast {s100|Charge}]==])
add("CW_WAR_CHARGE_INTERCEPT", "WARRIOR", "dps", { "solo", "pvp" }, [==[
#showtooltip
/startattack
/cast [nocombat,stance:1] {s100|Charge}; [combat,stance:3] {s20252|Intercept}; [nocombat,nostance:1] {s2457|Battle Stance}; [combat,nostance:3] {s2458|Berserker Stance}]==])
add("CW_WAR_VICTORY", "WARRIOR", "dps", { "solo" }, [==[
#showtooltip
/startattack
/cast {s0|Victory Rush}]==])
add("CW_WAR_BERSERK", "WARRIOR", "utility", { "pvp", "group" }, [==[
#showtooltip
/cast [nostance:3] {s2458|Berserker Stance}
/cast {s18499|Berserker Rage}]==])
add("CW_WAR_EXECUTE", "WARRIOR", "dps", { "group", "solo" }, [==[
#showtooltip
/startattack
/cast [stance:2] {s2457|Battle Stance}
/cast [mod:shift,@mouseover,harm,nodead] {s5308|Execute}; {s5308|Execute}]==])
add("CW_WAR_HS_CLEAVE", "WARRIOR", "dps", { "solo", "group" }, [==[
#showtooltip
/startattack
/cast [mod:shift] {s845|Cleave}; {s78|Heroic Strike}]==])
add("CW_WAR_TRINKETS", "WARRIOR", "dps", { "group", "pvp" }, [==[
#showtooltip
/use 13
/use 14]==])
add("CW_WAR_RAGE", "WARRIOR", "dps", { "group" }, [==[
#showtooltip
/cast {s2687|Bloodrage}
/use {i5631|Rage Potion}]==])
add("CW_WAR_SHOUTS", "WARRIOR", "utility", { "group", "solo" }, [==[
#showtooltip
/cast [mod:shift] {s1160|Demoralizing Shout}; {s6673|Battle Shout}]==])
