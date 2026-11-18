# Midalia: design decisions

Agreed in the grilling session of 17–18 November 2026. This file is the source of truth for the game; change it when a decision changes.

## The game

A broke international student lands in Milan with 15,500 euro in cash and owes the school 15,000. The goal is to finish a 30-day school year and leave the country.

- **Only game over:** wellbeing reaches zero.
- **Failing school never ends the game.** A missed exam is retaken later while living costs keep piling up.
- The character should always feel broke, so the player always wants to earn money.

## Platform and tools

- Godot 4, GDScript, in this repo.
- Windows PC first.
- Third-person camera. WASD to walk, mouse to look, Space to jump, E to talk or use a door, Tab for the phone.
- Autosave each time the player wakes up. One save slot, no manual saving.
- Look: normally proportioned, semi-realistic humans made funny through stiff, goofy animation and exaggerated faces.

## Talking to people

- The player types freely, by text on the phone or face to face. Face to face uses the same chat shown as speech bubbles, and outcomes are more likely to go the player's way.
- The game sorts each message into one of four tones:
  - **nice**: people help (loan, shelter, info)
  - **banter** (a little mean but nice): people become friends
  - **too nice**: people help but don't become friends
  - **mean**: people refuse; being mean to several people makes strangers mad
- **The game's rules decide every outcome.** The language model only writes the character's reply in their voice.
- Model: Gemma 3 4B, running locally (chosen 18 November 2026 after testing models from 270M to 4B; smaller ones were faster but less in character). Built so the model can be swapped.
- Tone is sorted by a separate small meaning-comparison model (bge-small) against example messages. Requests are spotted by keywords.
- Replies to requests and insults open with a line the game wrote, so the outcome is always clear; the model adds one line of personality.
- Everyone texts in casual English, swearing allowed. Italian appears only on signs and from strangers the player can't talk to.
- Each person remembers a short summary of past conversations (what was asked, rudeness, debts). The game keeps the summary and gives it to the model as background.

## People

- **Family, fixed every game:**
  - Mom and dad: each ask is a flat 100 euro. The chance they get mad doubles with every ask (5, 10, 20, 40, 80%) and resets after they blow up.
  - Sister: mood rolled once per day, 50% nasty (hurts wellbeing), 50% nice (raises it). On days 8 to 14 she is on her period: 85% nasty and a bigger wellbeing hit.
  - Grandpa: gives money at most once every two weeks, never gets mad.
  - Family money arrives only by bank transfer, so none can be received before the Italian account exists.
- **Everyone else, randomised each new game** with a hidden, fixed nature:
  - 95% two-faced: act friendly, then betray (cancel a couch offer late, steal cash while you sleep, not repay loans, talk behind your back)
  - 4% ok
  - 1% true friends who never betray
  - The first quest guarantees 1 true friend and 1 ok person among the people met.
- Two numbers drive outcomes: one **street cred** score for how everyone sees you, and a **private opinion** each person holds. Outcomes depend on both and on the person's hidden nature.
- Street cred needs balance: too low and people don't help or repay; high and people keep asking you for loans, favours and a place to stay.

## Stats

- **Wellbeing**: starts at 60%. Raised by shelter, passing exams, friends, food.
- **Money**: cash in pocket and, after opening an account, a bank balance.
- **Street cred**: starts at zero.
- **Notebook**: starts empty. Fills automatically with what people tell you (where the bank is, who has a couch, gossip about who can't be trusted, which may be a lie).

On screen while walking: wellbeing, cash and the clock, shown simply. Street cred, bank balance and the notebook are inside the phone.

## Money

- All money is cash until the player opens an Italian bank account.
- Opening the account: walk to the bank during opening hours (9:00 to 16:00) and spend 3 in-game hours. Cash can then be deposited at the counter.
- Tuition (15,000 euro) is paid by pressing pay in the university app on the phone, which needs the bank account. Unpaid tuition blocks exams. It does not affect wellbeing.
- Daily drain: food (skipping it lowers wellbeing). Weekly rent once the player has a permanent place.
- Money sources in the first build: family and borrowing from people met.

## Time

- One in-game day lasts 20 real minutes. The clock keeps running while the phone is open.
- At 5:00 the day ends. A player still on the street passes out.
- Sleeping in a bed skips to 9:00 and restores more wellbeing than a couch. Passing out on the street also skips to 9:00.

## Passing out on the street

Two wheels, spun by the player:

1. **Damage wheel** (always): how much wellbeing is lost, with segments such as 10, 20, 30, 40.
2. **Robbery wheel** (only when carrying cash): shows "robbed" and "safe" as if the odds were equal, styled like Russian roulette. It is rigged: the real chance of "robbed" is 60%. Robbed means the cash on you is taken. Bank money is never touched.

## School

- 30 in-game days. Exams on days 10, 20 and 30.
- Tuition must be paid before the first exam.
- Passing an exam depends on hours the player chose to spend studying.

## Phone

First build: WhatsApp (texting), banking app (locked until the account exists), university app (shows the debt, has the pay button). Voice calls come later.

## Quests

1. **First quest:** land in Italy, get an Italian number, find shelter for the night, open a bank account.
2. **Second quest:** find permanent shelter until school starts.

### The second quest: a room of your own

Agreed 18 November 2026.

- **Two ways to find a room:**
  - Ask someone you met, by text or face to face. It is a bigger ask than a couch; friends are more likely to say yes. Their spare room is cheap (90 euro a week).
  - Read the notice board in the university hall. It always has three rooms, one in each student flat, let by strangers at 140, 165 and 190 euro a week. Reading it puts the landlords in the phone.
- **Moving in:** ring the bell at the flat and pay the first week on the spot. Rent is then due every 7 days and is taken on waking, from the pocket first and then the bank. Unable to pay means being thrown out.
- **Home gives:** a bed (usable from 21:00, restores more than a couch) and a kitchen for cheap meals. At 5:00 at home the player drops into bed instead of passing out.
- **A two-faced flatmate** may do one of these on any night the player sleeps at home:
  - steal a share of the cash in the player's pocket
  - spread a secret about the player; the player finds out in the morning and loses wellbeing
  - raise the rent (once)
  - text in the evening that the player must be out that night
- The flatmate has the same hidden nature as everyone else; ok people and true friends never do any of this.

### Food

- One meal a day counts. Eat at the station bar (12 euro), or cook at home once the player has a room (4 euro).
- Waking up after a day without a meal costs wellbeing.

## First build

Night one and day two only, about 30 real minutes of play.

- Land at 18:00. The party starts at 21:00. The player may also explore the city that night.
- At the party the player meets about 6 randomised students face to face, gets their numbers, and needs one to offer a couch before 5:00.
- A two-faced host can cancel the offer late at night, or let the player stay and take some of their cash.
- Day two: open the bank account.
- Ends with a "you survived" screen once the player has slept somewhere (or passed out and spun the wheels) and opened the account.
- City: one small neighbourhood with the station, the party flat, the bank, the university building and two or three student flats.

## Build order

The player-facing result of each step is played before the next starts.

1. Texting test with the small model, no 3D
2. Walking around the neighbourhood
3. The phone and its three apps
4. The party, meeting people, shelter, the 5:00 pass-out and both wheels
5. Day two: the bank, then the "you survived" screen

## Tuning

All numbers (wellbeing gains and losses, food prices, couch odds, loan sizes) live in one settings file and are tuned by hand after playing.

## Later

- Doing bad stuff to earn money
- Clubs and other night venues
- Voice calls
- More of the city
- Lending money to others
- Multiple character classes with different starting conditions
- Randomised starting money
- Music
