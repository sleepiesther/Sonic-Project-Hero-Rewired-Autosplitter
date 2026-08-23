state("Sonic Project Hero Rewired"){}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");

    vars.Helper.LoadSceneManager = true;

    settings.Add("levelComplete", true, "Split on level completion");
    settings.Add("levelEnter", true, "Start on level entry");
    settings.Add("titleClose", true, "Start on closing the title screen");
}

init
{
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        var pc = mono["PlayerCore"];
        var gm = mono["GameManager"];
        var pm = mono["PauseMenu"];
        var qp = mono["QuitPopup"];
        var pp = mono["PlayerPhysics"];

        vars.Helper["timeAlive"] = mono.Make<float>(pc, "instance", pc["timeAlive"]);
        vars.Helper["quitMenuLockedIndex"] = mono.Make<int>(gm, "instance", gm["pause"], pm["quitPopup"], qp["lockedSelectedOptionIndex"]);
        vars.Helper["isQuitOptionLocked"] = mono.Make<bool>(gm, "instance", gm["pause"], pm["quitPopup"], qp["selectionLocked"]);
        vars.Helper["quitMenuActive"] = mono.Make<bool>(gm, "instance", gm["pause"], pm["quitPopup"], qp["active"]);
        vars.Helper["physicsEnabled"] = mono.Make<bool>(pc, "instance", pc["physics"], 0x10, 0x39);

        return true;
    });

    //Variable for tallying IGT from multiple levels into one
    vars.totalTime = 0;
    vars.timeAliveReduction = 0;
    vars.quitting = false;
    old.quitMenuActive = false;
}

update
{
    current.activeScene = vars.Helper.Scenes.Active.Name ?? current.activeScene;
    current.loadingScene = vars.Helper.Scenes.Loaded[0].Name ?? current.loadingScene;

    //If the IGT has been reset to 0 (e.g. by finishing or restarting a level), add the old IGT to the tally
    if ((current.timeAlive == 0 && old.timeAlive != 0 && current.activeScene != "HubEntrance") || (current.timeAlive < old.timeAlive && old.activeScene == "HubEntrance")){
        vars.totalTime += old.timeAlive - vars.timeAliveReduction;
        vars.timeAliveReduction = 0;
    }

    //If the player has locked into the "Quit" option on the quit menu and the menu has just become inactive, they have quit out of the level
    if (current.quitMenuLockedIndex == 0 && current.isQuitOptionLocked && old.quitMenuActive && !current.quitMenuActive){
        vars.quitting = true;
        vars.Log("quit start");
    }

    //If the load has finished, the player has finished quitting out of the level
    if (vars.quitting && current.loadingScene == current.activeScene){
        vars.quitting = false;
        vars.Log("quit done");
    }
}

split
{
    //Split when going from in level to hub, only via goal ring and not via quitting in the menu
    if (current.activeScene != "HubEntrance" && current.loadingScene == "HubEntrance" && old.loadingScene != "HubEntrance" && !vars.quitting && settings["levelComplete"]){
        return true;
    }
}

start
{
    //Start when closing the title screen
    if (current.activeScene == "HubEntrance" && current.physicsEnabled == true && old.physicsEnabled == false && settings["titleClose"]){
        vars.timeAliveReduction = current.timeAlive;
        return true;
    }

    //Start when entering a level from the hub
    if (current.activeScene == "HubEntrance" && current.loadingScene != "HubEntrance" && settings["levelEnter"]){
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
    return TimeSpan.FromSeconds(vars.totalTime + current.timeAlive - vars.timeAliveReduction);
}

isLoading
{
    //Forces the auto increment of game time to stop, therefore meaning game time only updates when memory is read
    return true;
}