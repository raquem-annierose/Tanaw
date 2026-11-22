--!strict
-- Conversation starters for the question balls on the SkyTerrace tables (see QuestionBallService).
-- Keep them light and never ask for personal info (real name, age, school, location, socials).

local TableQuestions = {
	-- CollectionService tag on the ball parts in Studio.
	Tag = "QuestionBall",
	-- How long a question stays up (seconds).
	ShowSeconds = 30,
	-- Minimum time between clicks on the same ball (seconds).
	Cooldown = 2,
	List = {
		-- getting to know each other
		"Ano ang first impression mo sa'kin? Be honest haha",
		"Ano ang isang bagay tungkol sa'yo na hindi alam ng karamihan?",
		"Introvert o extrovert ka? Paano mo nalaman?",
		"Ano ang love language mo sa friends mo?",
		"Paano ka mag-comfort ng kaibigan na malungkot?",
		"Ano ang green flag na hinahanap mo sa isang kaibigan?",
		"Ano ang red flag na hindi mo kayang i-tolerate sa friendship?",
		"Paano mo ide-describe ang sarili mo in 3 words?",
		"Ano ang pet peeve mo na medyo petty pero totoo?",
		"Ano ang song na parang soundtrack ng buhay mo ngayon?",
		"Ano ang ginagawa mo pag overthinking ka?",
		"Mas gusto mo bang kausap ang marami o isa lang na close?",
		"Ano ang isang ugali mo na gusto mong baguhin?",
		"Ano ang pinaka-proud ka sa sarili mo this year?",
		"Ano ang comfort person mo, at bakit sila?",
		-- deep
		"Ano ang pinaka-kinatatakutan mo sa future?",
		"Kailan ka huling umiyak, at bakit?",
		"Ano ang isang bagay na sana sinabi mo sa younger self mo?",
		"Ano ang lesson na natutunan mo the hard way?",
		"Ano ang pinaka-mabigat na pinagdaanan mo na nalampasan mo?",
		"Ano ang dream mo na hindi mo pa nasasabi sa iba?",
		"Kung pwede mong ulitin ang isang araw sa buhay mo, alin?",
		"Ano ang ibig sabihin ng 'home' para sa'yo?",
		"Ano ang pinaka-regret mo na hindi mo ginawa?",
		"Kailan ka pinaka-naging totoo sa sarili mo?",
		"Ano ang bagay na madalas mong i-sacrifice para sa iba?",
		"Ano ang nagpapagaan ng loob mo pag sobrang bigat na?",
		"Naniniwala ka ba sa 'everything happens for a reason'?",
		"Ano ang hindi mo makakalimutang sinabi sa'yo ng isang tao?",
		"Ano ang version ng sarili mo na gusto mong maabot in 5 years?",
		"Ano ang isang bagay na hindi mo pa napapatawad sa sarili mo?",
		"Ano ang pinaka-masayang memory mo na simple lang?",
		"Mas takot ka bang mabigo o hindi man lang sumubok?",
		"Ano ang bagay na gusto mong mas maintindihan ng mga tao tungkol sa'yo?",
		"Ano ang pinaka-tapang na ginawa mo?",
		"Kung may isang bagay kang pwedeng sabihin sa lahat ng tao, ano?",
		-- light, para may pahinga
		"Kung isang kanta ka, anong kanta ka?",
		"Sunrise o sunset ka? Bakit?",
		"Ano ang comfort food mo pag malungkot ka?",
		"Ano ang small win mo today?",
	},
}

return TableQuestions
