class_name Settings
## Every tunable number in the game lives here. Change freely after playing.

# --- Language model ---
## Models the texting test can switch between. The first one is the default.
const MODELS := {
	"Gemma 3 4B": "res://models/gemma-3-4b-it-Q4_K_M.gguf",
	"LFM2 700M": "res://models/LFM2-700M-Q8_0.gguf",
	"Gemma 3 1B": "res://models/gemma-3-1b-it-Q8_0.gguf",
	"Qwen3 0.6B": "res://models/Qwen3-0.6B-Q8_0.gguf",
	"LFM2.5 350M": "res://models/LFM2.5-350M-Q8_0.gguf",
	"Gemma 3 270M": "res://models/gemma-3-270m-it-Q8_0.gguf",
}
## Small model that compares meanings; used to sort the tone of a message.
const TONE_MODEL := "res://models/bge-small-en-v1.5-q8_0.gguf"
## How many of the closest example messages decide the tone.
const TONE_CLOSEST_EXAMPLES := 3
const REPLY_TEMPERATURE := 0.8
const REPLY_MAX_CHARS := 220

# --- Starting stats ---
const START_WELLBEING := 60
const START_CASH := 15500
const START_STREET_CRED := 0

# --- Natures of the people you meet (must add up to 100) ---
const NATURE_ODDS := {"two_faced": 95, "ok": 4, "true_friend": 1}

# --- How a message's tone changes what a person thinks of you (-100..100) ---
const OPINION_CHANGE := {"nice": 5, "banter": 10, "too_nice": 2, "mean": -20}
## Opinion a person needs before banter turns them into a friend.
const FRIEND_OPINION := 20

# --- Chance a person says yes when you ask for something, by tone ---
const GRANT_CHANCE := {"nice": 0.60, "too_nice": 0.70, "banter": 0.35, "mean": 0.0}
## Added per point of the person's opinion of you.
const GRANT_PER_OPINION := 0.004
## Added per point of street cred.
const GRANT_PER_CRED := 0.002
## Added when you ask face to face instead of by text.
const GRANT_IN_PERSON_BONUS := 0.15

# --- Punishments ---
const REJECTED_WELLBEING := -5
## Being mean to this many different people makes strangers mad at you.
const MEAN_PEOPLE_LIMIT := 2
const STRANGERS_MAD_CRED := -10
const STRANGERS_MAD_WELLBEING := -5

# --- Rewards ---
const NEW_FRIEND_WELLBEING := 8
const NEW_FRIEND_CRED := 3
const LOAN_AMOUNT := 50

# --- School ---
const TUITION := 15000

# --- Family ---
## Money a parent sends per ask.
const PARENT_AMOUNT := 100
## Chance a parent gets mad on the first ask; it doubles with every ask after.
const PARENT_MAD_CHANCE := 0.05
const PARENT_MAD_WELLBEING := -8
const GRANDPA_AMOUNT := 150
const GRANDPA_DAYS_BETWEEN_GIFTS := 14
const SISTER_NASTY_CHANCE := 0.5
const SISTER_NASTY_CHANCE_PERIOD := 0.85
const SISTER_PERIOD_FIRST_DAY := 8
const SISTER_PERIOD_LAST_DAY := 14
const SISTER_NICE_WELLBEING := 6
const SISTER_NASTY_WELLBEING := -6
const SISTER_NASTY_WELLBEING_PERIOD := -12

# --- The first night ---
const PARTY_SIZE := 6
const PARTY_START_HOUR := 21
## Hour the night ends. Still on the street then, and you pass out.
const PASS_OUT_HOUR := 5
## Hour you wake up after sleeping or passing out.
const WAKE_HOUR := 9
const COUCH_WELLBEING := 10
const BED_WELLBEING := 20
## What a two-faced host does after offering their couch (the rest of the time, nothing).
const BETRAY_CANCEL_CHANCE := 0.35
const BETRAY_STEAL_CHANCE := 0.35
## Share of your cash a thieving host takes.
const STEAL_SHARE_MIN := 0.10
const STEAL_SHARE_MAX := 0.30

# --- Passing out on the street ---
## The damage wheel's segments: wellbeing lost.
const STREET_DAMAGE := [10, 20, 30, 40]
## The robbery wheel looks 50/50. This is the real chance of "robbed".
const ROBBED_CHANCE := 0.6

# --- The bank ---
const BANK_OPENS_HOUR := 9
const BANK_CLOSES_HOUR := 16
## In-game hours it takes to open an account.
const BANK_ACCOUNT_HOURS := 3

# --- Time ---
## Real minutes one in-game day lasts.
const DAY_REAL_MINUTES := 20.0
## Hour of day the game starts at.
const START_HOUR := 18

# --- Walking ---
const WALK_SPEED := 4.0
const RUN_SPEED := 7.5
const JUMP_SPEED := 5.0
const GRAVITY := 14.0
const CAMERA_DISTANCE := 4.5
const CAMERA_DISTANCE_INDOORS := 2.4
const MOUSE_SENSITIVITY := 0.003
