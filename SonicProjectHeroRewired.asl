state("Sonic Project Hero Rewired"){}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/unity-help")).CreateInstance("Unity");

    settings.Add("levelComplete", true, "Split on level completion");
    settings.Add("levelEnter", true, "Start on level entry");
    settings.Add("titleClose", true, "Start on closing the title screen");
}

init
{
    vars.timeAlive = vars.Helper.Make<float>("PlayerCore", 0, "instance", "timeAlive");
    vars.respawning = vars.Helper.Make<bool>("PlayerCore", 0, "instance", "respawning");
    vars.physicsEnabled = vars.Helper.Make<bool>("PlayerCore", 0, "instance", "physics", 0x10, 0x39);

    vars.quitMenuLockedIndex = vars.Helper.Make<int>("GameManager", 0, "instance", "pause", "quitPopup", "lockedSelectedOptionIndex");
    vars.isQuitOptionLocked = vars.Helper.Make<bool>("GameManager", 0, "instance", "pause", "quitPopup", "selectionLocked");
    vars.restarting = vars.Helper.Make<bool>("GameManager", 0, "instance", "pause", "restarting");

    //Variable for tallying IGT from multiple levels into one
    vars.totalTime = 0;
    vars.timeAliveReduction = 0;
    vars.quitting = false;

    old.physicsEnabled = true;
    current.activeScene = "";

    vars.levelSceneNames = new List<string>() {"Tutorial", "Windmill Isle", "Emerald Coast", "Sigil Archipelago", "Metal Harbour", "KingdomValley", "1-1", "1-2", "FHTower5"};
}

update
{
    current.activeScene = vars.Helper.SceneManager.Current.Name != null && vars.Helper.SceneManager.Current.Name != "" ? vars.Helper.SceneManager.Current.Name : current.activeScene;
    current.physicsEnabled = vars.physicsEnabled.Current ?? current.physicsEnabled;

    //This is sinful code but its the only way i could get this working im sorry
    foreach(dynamic scene in vars.Helper.SceneManager.Scenes){
        current.loadingScene = scene.Name;
        break;
    }

    //If the IGT has been reset to 0 (e.g. by finishing or restarting a level), add the old IGT to the tally
    if ((vars.respawning.Old && !vars.respawning.Current && vars.timeAlive.Current == 0) || (vars.restarting.Current && vars.timeAlive.Current == 0) || (vars.timeAlive.Current == 0 && vars.timeAlive.Old != 0 && current.loadingScene == "HubEntrance") || (vars.timeAlive.Current < vars.timeAlive.Old && old.activeScene == "HubEntrance")){
        vars.totalTime += vars.timeAlive.Old - vars.timeAliveReduction;
        vars.timeAliveReduction = 0;
    }

    //If the player has locked into the "Quit" option on the quit menu and the menu has just become inactive, they have quit out of the level
    if (vars.quitMenuLockedIndex.Current == 0 && vars.isQuitOptionLocked.Current && !vars.quitting){
        vars.quitting = true;
    }

    //If the load has finished, the player has finished quitting out of the level
    if (vars.quitting && current.loadingScene == current.activeScene){
        vars.quitting = false;
    }
}

split
{
    //Split when going from in level to hub, only via goal ring and not via quitting in the menu
    if (vars.levelSceneNames.Contains(current.activeScene) && current.loadingScene == "HubEntrance" && old.loadingScene != "HubEntrance" && !vars.quitting && settings["levelComplete"]){
        return true;
    }
}

start
{
    //Start when closing the title screen
    if (current.activeScene == "HubEntrance" && current.loadingScene == "HubEntrance" && current.physicsEnabled == true && old.physicsEnabled == false && !vars.restarting.Current && settings["titleClose"]){
        vars.timeAliveReduction = vars.timeAlive.Current;
        return true;
    }

    //Start when entering a level from the hub
    if (old.activeScene == "HubEntrance" && vars.levelSceneNames.Contains(current.activeScene) && settings["levelEnter"]){
        vars.timeAliveReduction = 0;
        return true;
    }
}

onStart
{
    vars.totalTime = 0;
}

gameTime
{
    return TimeSpan.FromSeconds(vars.totalTime + vars.timeAlive.Current - vars.timeAliveReduction);
}

isLoading
{
    //Forces the auto increment of game time to stop, therefore meaning game time only updates when memory is read
    return true;
}