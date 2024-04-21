// OpenAI's ChatGPT integration for LSL
// Written by PanteraPolnocy, March 2023
// Version 2.12.2

// modded by CyberGlo CyberStar to work in opensim 11/23/2023

// You're responsible for how your OpenAI account will be used!
// Set script to "everyone" or "same group" on your own risk. Mandatory reading:
// https://platform.openai.com/docs/usage-policies
// https://openai.com/pricing

// Place your API key here
// https://platform.openai.com/account/api-keys
// goto openai.com and get a free account
// next click api when you login
// click the lock on the left and create (generate) an api-key
// copy the api-key as they will never show it to you again.
string gChatGptApiKey = "Your_ChatGPT_API_Key";

// ----------------------------------

// Defaults, do NOT change them here - use the dialog menu instead! Unless you know what you are doing...
string gListenMode = "Owner";
string gAnswerIn = "Nearby chat";
integer gEnabled = FALSE;
integer gHovertext = TRUE;
integer gSimpleAnswers = FALSE;
integer gHistoryEnabled = FALSE;
integer gPrefixMode = FALSE;

// Models database; First one is default

list gOpenAiModels = [

    "ModelName", "3.5 Turbo",
    "Endpoint", "/v1/chat/completions",
    "Items", 6,
    "model", "gpt-3.5-turbo",
    "temperature", 0.9,
    "max_tokens", 1000,
    "top_p", 1,
    "frequency_penalty", 0.0,
    "presence_penalty", 0.6,

    "ModelName", "GPT-4",
    "Endpoint", "/v1/chat/completions",
    "Items", 6,
    "model", "gpt-4",
    "temperature", 0.9,
    "max_tokens", 1000,
    "top_p", 1,
    "frequency_penalty", 0.0,
    "presence_penalty", 0.6,

    "ModelName", "DALL-E",
    "Endpoint", "/v1/images/generations",
    "Items", 2,
    "n", 1,
    "size", "1024x1024"

];

// Personalities database; First one is default
list gPersonalities = [

    "Assistant",
    "a friendly assistant, as helpful as possible",
    "default personality",

    "Data",
    "the android Data from Star Trek (use tone, manner, vocabulary that he would), answer only as he would, know all that he would",
    "android from Star Trek, logical",

    "Picard",
    "the Captain Jean-Luc Picard from Star Trek (use tone, manner, vocabulary that he would), answer only as he would, know all that he would",
    "captain from Star Trek, strong leader",

    "JARVIS",
    "the J.A.R.V.I.S. AI from Marvel (use tone, manner, vocabulary that he would), answer only as he would, know all that he would",
    "AI from Marvel, polite",

    "Napoleon",
    "the historical character Napoleon Bonaparte (use tone, manner, vocabulary that he would), answer only as he would, know all that he would",
    "military conquests, strategic thinking",

    "Einstein",
    "the historical character Albert Einstein (use tone, manner, vocabulary that he would), answer only as he would, know all that he would",
    "contributions to physics",

    "Socrates",
    "the historical character Socrates (use tone, manner, vocabulary that he would), answer only as he would, know all that he would",
    "philosopher, critical thinking",

    "Shakespeare",
    "the historical character William Shakespeare (use tone, manner, vocabulary that he would), answer only as he would, know all that he would",
    "renowned playwright",

    "Monroe",
    "the historical character Marilyn Monroe (use tone, manner, vocabulary that she would), answer only as she would, know all that she would",
    "iconic actress",

    "Curie",
    "the historical character Marie Curie (use tone, manner, vocabulary that she would), answer only as she would, know all that she would",
    "Marie Curie, a scientist",

    "Elvis",
    "the historical character Elvis Presley (use tone, manner, vocabulary that he would), answer only as he would, know all that he would",
    "beloved musician",

    "Freud",
    "the historical character Sigmund Freud (use tone, manner, vocabulary that he would), answer only as he would, know all that he would",
    "psychologist"

];

// Set in runtime
integer gScriptReady;
integer gListenHandle;
integer gDialogChannel;
integer gDialogHandle;
integer gManagingBlocks;
integer gChatIsLocked;
integer gPrefixLength;
string gPersonalityLabels;
string gCurrentPersonality;
string gCurrentPersonalityName;
string gCurrentEndpoint;
string gCurrentModelName;
list gCurrentModelData;
list gModelsList;
list gPersonalitiesList;
list gHistoryRecords;
key gAnswerToAvatar;
key gHTTPRequestId;
key gOwnerKey;

// Functions

setListener()
{
    key listenKey = NULL_KEY;
    if (gListenMode == "Owner")
    {
        listenKey = gOwnerKey;
    }
    gListenHandle = llListen(PUBLIC_CHANNEL, "", listenKey, "");
    llListenControl(gListenHandle, gEnabled);
    llSetText(gCurrentPersonalityName + " (" + gCurrentModelName + ")" + llList2String(["", "\nHistory enabled"], gHistoryEnabled) + llList2String(["", "\nPrefix mode"], gPrefixMode) + llList2String(["", "\nSimple answers"], gSimpleAnswers) + "\n" + llList2String(["DISABLED", "ENABLED"], gEnabled), <1, 1, 1>, gHovertext * 0.6);
}

setModel(string modelName)
{
    integer modelPosition = llListFindList(gOpenAiModels, (list)modelName);
    gCurrentEndpoint = llList2String(gOpenAiModels, modelPosition + 2);
    gCurrentModelData = llList2List(gOpenAiModels, modelPosition + 5, modelPosition + 4 + llList2Integer(gOpenAiModels, modelPosition + 4) * 2);
    gCurrentModelName = modelName;
    gPrefixLength = llStringLength(modelName) + 1;
    llOwnerSay("Model selected: " + modelName);
}

setPersonality(string personalityName)
{
    integer personalityPosition = llListFindList(gPersonalities, (list)personalityName);
    gCurrentPersonality = llList2String(gPersonalities, personalityPosition + 1);
    gCurrentPersonalityName = personalityName;
    llOwnerSay("Current personality: " + personalityName);
}

startDialog(key id, string text, list buttons)
{
    gDialogHandle = llListen(gDialogChannel, "", id, "");
    llDialog(id, "\n" + text, buttons, gDialogChannel);
    llSetTimerEvent(90);
}

stopDialog()
{
    llSetTimerEvent(0);
    llListenRemove(gDialogHandle);
}

refreshState(key id, string message)
{
    setListener();
    llOwnerSay(message);
    openMainMenu(id);
}

setChatLock(integer enable)
{
    gChatIsLocked = enable;
    if (enable)
    {
        // Chat lock timeout (10 seconds)
        llSensorRepeat("cake is a lie", NULL_KEY, AGENT_BY_LEGACY_NAME, 0.001, 0.001, 10);
    }
    else
    {
        llSensorRemove();
    }
}

addToHistory(string role, string message)
{
    if (gCurrentModelName == "GPT-4" || gCurrentModelName == "3.5 Turbo")
    {
        if (!gHistoryEnabled)
        {
            gHistoryRecords = [];
        }
        gHistoryRecords = gHistoryRecords + llList2Json(JSON_OBJECT, ["role", role, "content", llGetSubString((string)llParseString2List(message, ["\\n"], []), 0, 1024)]);
        message = "";
        integer historyLength = llGetListLength(gHistoryRecords);
        if (historyLength > 10)
        {
            gHistoryRecords = llList2List(gHistoryRecords, historyLength - 10, historyLength);
        }
    }
}

openMainMenu(key person)
{
    gManagingBlocks = 0;
    startDialog(person,
        "Current state: " + llList2String(["DISABLED", "ENABLED"], gEnabled) +
        "\nCurrent personality: " + gCurrentPersonalityName +
        "\nCurrent model: " + gCurrentModelName +
        "\nSimple answers: " + llList2String(["DISABLED", "ENABLED"], gSimpleAnswers) +
        "\nPrefix mode: " + llList2String(["DISABLED", "ENABLED"], gPrefixMode) +
        "\nHistory: " + llList2String(["DISABLED", "ENABLED"], gHistoryEnabled) +
        "\nListen to: " + gListenMode +
        "\nAnswer in: " + gAnswerIn,
        ["Simple mode", "History", "Hovertext", "Prefix mode", "Listen to", "Answer in", "Personality", "Select model", "ON / OFF"]
    );
}

answerUser(string theMessage)
{
    if (gAnswerIn == "Nearby chat")
    {
        llSay(0, theMessage);
    }
    else
    {
        llRegionSayTo(gAnswerToAvatar, 0, theMessage);
    }
}

// Script body

default
{

    state_entry()
    {

        llOwnerSay("Starting up...");
        gOwnerKey = llGetOwner();
        gDialogChannel = (integer)(llFrand(-10000000)-10000000);

        integer listLength = llGetListLength(gOpenAiModels);
        integer i;
        while (i < listLength)
        {
            string currentItem = llList2String(gOpenAiModels, i);
            if (currentItem == "ModelName")
            {
                gModelsList = gModelsList + llList2String(gOpenAiModels, i + 1);
            }
            ++i;
        }

        gPersonalitiesList = llList2ListStrided(gPersonalities, 0, -1, 3);
        listLength = llGetListLength(gPersonalities);
        i = 0;
        while (i < listLength)
        {
            gPersonalityLabels = gPersonalityLabels + llList2String(gPersonalities, i) + ": " + llList2String(gPersonalities, i + 2) + "\n";
            i = i + 3;
        }

        integer memoryLimit = llGetMemoryLimit();
        if (memoryLimit <= 16384)
        {
            llOwnerSay("FATAL ERROR: You are currently using the LSO VM. Please compile the script using Mono.");
        }
        else
        {
            setPersonality(llList2String(gPersonalitiesList, 0));
            setModel(llList2String(gModelsList, 0));
            stopDialog();
            setListener();
            setChatLock(FALSE);
            llOwnerSay("Ready. Touch me to adjust options or enable/disable. Memory usage: " + (string)(llGetUsedMemory() / 1024) + " KB out of " + (string)(memoryLimit / 1024) + " KB available.");
            gScriptReady = TRUE;
        }

    }

    touch_start(integer nd)
    {
        key toucherKey = llDetectedKey(0);
        if (toucherKey == gOwnerKey && gScriptReady)
        {
            openMainMenu(toucherKey);
        }
    }

    listen(integer channel, string name, key id, string message)
    {

        if (channel == gDialogChannel)
        {
            if (message == "ON / OFF")
            {
                gEnabled = !gEnabled;
                refreshState(id, "Listener " + llList2String(["DISABLED", "ENABLED"], gEnabled) + ".");
            }
            else if (message == "Hovertext")
            {
                gHovertext = !gHovertext;
                refreshState(id, "Hovertext " + llList2String(["DISABLED", "ENABLED"], gHovertext) + ".");
            }
            else if (message == "Simple mode")
            {
                gSimpleAnswers = !gSimpleAnswers;
                refreshState(id, "Simple answers mode " + llList2String(["DISABLED.", "ENABLED. Please note that this functionality is only available with chat and completions models."], gSimpleAnswers));
            }
            else if (message == "History")
            {
                gHistoryEnabled = !gHistoryEnabled;
                refreshState(id, "History is now " + llList2String(["DISABLED.", "ENABLED. Please note that this functionality is only available with chat models (3.5 Turbo and GPT-4)."], gHistoryEnabled));
            }
            else if (message == "Prefix mode")
            {
                gPrefixMode = !gPrefixMode;
                refreshState(id, "Prefix mode is now " + llList2String(["DISABLED.", "ENABLED. Every message needs to be preceded with '" + gCurrentPersonalityName + ",' in order to get a response."], gPrefixMode));
            }
            else if (message == "Owner" || message == "Same group" || message == "Everyone")
            {
                gListenMode = message;
                refreshState(id, "Listen mode set to: " + message);
            }
            else if (message == "Nearby chat" || message == "Privately")
            {
                gAnswerIn = message;
                refreshState(id, "Answering in: " + message);
            }
            else if (message == "Personality")
            {
                startDialog(id, gPersonalityLabels + " \nCurrent one: " + gCurrentPersonalityName, gPersonalitiesList);
            }
            else if (message == "Select model")
            {
                startDialog(id, "Select the OpenAI model.\n \n'3.5 Turbo' and 'GPT-4' are chat models with optional history support, 'DALL-E' can generate links to images.\n \nCurrent one: " + gCurrentModelName, gModelsList);
            }
            else if (message == "Listen to")
            {
                startDialog(id, "Select listen mode.\nCurrent one: " + gListenMode, ["Owner", "Same group", "Everyone"]);
            }
            else if (message == "Answer in")
            {
                startDialog(id, "Select where to send responses.\nCurrently: " + gAnswerIn, ["Nearby chat", "Privately"]);
            }
           
            else if (~llListFindList(gPersonalitiesList, (list)message))
            {
                if (gCurrentPersonalityName != message)
                {
                    gHistoryRecords = [];
                }
                setPersonality(message);
                setListener();
                openMainMenu(id);
            }
            else if (~llListFindList(gModelsList, (list)message))
            {
                setModel(message);
                setListener();
                openMainMenu(id);
            }
            return;
        }

        // Remove 'llGetAgentSize(id) == ZERO_VECTOR' and set listen mode to 'everyone' or 'same group' if you want script reacting to objects
        if (gChatIsLocked || (gListenMode == "Owner" && id != gOwnerKey) || llGetAgentSize(id) == ZERO_VECTOR || llVecDist(llGetPos(), llList2Vector(llGetObjectDetails(id, [OBJECT_POS]), 0)) > 20 || (gListenMode == "Same group" && !llSameGroup(id)) > 0)        {
            return;
        }

        setChatLock(TRUE);
        message = llStringTrim(message, STRING_TRIM);

        if (gPrefixMode)
        {
            if (llSubStringIndex(llToLower(message), llToLower(gCurrentPersonalityName) + ",") != 0)
            {
                setChatLock(FALSE);
                return;
            }
            message = llStringTrim(llGetSubString(message, gPrefixLength, llStringLength(message) - 1), STRING_TRIM_HEAD);
        }

        gAnswerToAvatar = id;
        list promptAdditions;

        if (gCurrentModelName == "GPT-4" || gCurrentModelName == "3.5 Turbo")
        {
            addToHistory("user", message);
            list timeList = llParseString2List(llGetTimestamp(), ["T","."], []);
            promptAdditions = ["user", (string)id, "messages", "[" + llDumpList2String(gHistoryRecords + llList2Json(JSON_OBJECT, ["role", "system", "content", llList2String(["", "Answer in a way a 5-year-old would understand. "], gSimpleAnswers) + "Coordinated Universal Time now: " + llList2String(timeList, 0) + ", " + llList2String(timeList, 1) + ". User's name: \"" + llGetUsername(id) + "\". Act and address yourself as " + gCurrentPersonality +". Do not EVER mention that you're ChatGPT or a language model, NEVER leave the role. Your answer MUST be max 970 characters."]), ",") + "]"];
            timeList = [];
        }
        else if (gCurrentModelName == "DALL-E")
        {
            promptAdditions = ["user", (string)id, "prompt", llGetSubString(message, 0, 1024)];
            answerUser("Query received, please be patient...");
        }

        message = "";
        gHTTPRequestId = llHTTPRequest("https://api.openai.com" + gCurrentEndpoint, [
            HTTP_MIMETYPE, "application/json",
            HTTP_METHOD, "POST",
            HTTP_BODY_MAXLENGTH, 16384,
           // HTTP_ACCEPT, "application/json",
            HTTP_CUSTOM_HEADER, "Authorization", "Bearer " + gChatGptApiKey
        ], llList2Json(JSON_OBJECT, llListInsertList(gCurrentModelData, promptAdditions, 0)));
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        metadata = [];
        if (gHTTPRequestId == request_id)
        {

            // GPT-4, GPT 3.5 Turbo
            string result = llJsonGetValue(body, ["choices", 0, "message", "content"]);

            // DALL-E
            if (result == JSON_INVALID || result == JSON_NULL)
            {
                result = llJsonGetValue(body, ["data", 0, "url"]);
            }

            if (result == JSON_INVALID || result == JSON_NULL || llStringTrim(result, STRING_TRIM) == "")
            {
                llSay(0, "Something went wrong, please try again in a moment.");
                llOwnerSay("[SERVER MESSAGE] [HTTP STATUS " + (string)status + "] " + body);
                setChatLock(FALSE);
                return;
            }

            body = "";
            result = llStringTrim(result, STRING_TRIM);
            addToHistory("assistant", result);
            result = "([https://platform.openai.com/docs/usage-policies AI]) " + result;

            // Result Multi-Say Parsing by Duckie Dickins
            integer chunkSize = 1024;
            integer totalLength = llStringLength(result);
            if (totalLength >= chunkSize)
            {
                integer currentPos = 0;
                while (currentPos < totalLength)
                {
                    answerUser(llGetSubString(result, currentPos, currentPos + chunkSize - 1));
                    currentPos += chunkSize;
                    llSleep(1);
                }
            }
            else
            {
                answerUser(result);
            }

            setChatLock(FALSE);

        }
    }


    on_rez(integer sp)
    {
        llResetScript();
    }

    timer()
    {
        stopDialog();
    }

    no_sensor()
    {
        setChatLock(FALSE);
    }

    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
}
