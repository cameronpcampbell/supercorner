--!strict

local types = require("./types")

type NormalizedCorners = types.NormalizedCorners

-- Corner indices: 1=TL, 2=TR, 3=BR, 4=BL
-- Adjacency (hardcoded):
--   TL: TR via top(width),  BL via left(height)
--   TR: TL via top(width),  BR via right(height)
--   BR: BL via bottom(width), TR via right(height)
--   BL: BR via bottom(width), TL via left(height)

local function distribute_and_normalize(
	width: number,
	height: number,
	top_left_radius: number,
	top_right_radius: number,
	bottom_right_radius: number,
	bottom_left_radius: number
): NormalizedCorners
	local r = { top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius }
	local b = { -1.0, -1.0, -1.0, -1.0 }

	-- Sort indices by radius descending (insertion sort, 4 elements)
	local order = { 1, 2, 3, 4 }

	for i = 2, 4 do
		local key = order[i]
		local key_r = r[key]
		local j = i - 1

		while j >= 1 and r[order[j]] < key_r do
			order[j + 1] = order[j]
			j -= 1
		end

		order[j + 1] = key
	end

	for _, ci in order do
		local radius = r[ci]

		-- Look up two adjacent corners and their shared side lengths
		local a1, s1, a2, s2
		if ci == 1 then     a1, s1, a2, s2 = 2, width, 4, height     -- TL
		elseif ci == 2 then a1, s1, a2, s2 = 1, width, 3, height     -- TR
		elseif ci == 3 then a1, s1, a2, s2 = 4, width, 2, height     -- BR
		else                a1, s1, a2, s2 = 3, width, 1, height end  -- BL

		local adj1_r, adj1_b = r[a1], b[a1]
		local budget1 = if radius == 0 and adj1_r == 0 then 0
			elseif adj1_b >= 0 then s1 - adj1_b
			else (radius / (radius + adj1_r)) * s1

		local adj2_r, adj2_b = r[a2], b[a2]
		local budget2 = if radius == 0 and adj2_r == 0 then 0
			elseif adj2_b >= 0 then s2 - adj2_b
			else (radius / (radius + adj2_r)) * s2

		local min_budget = math.min(budget1, budget2)
		b[ci] = min_budget

		if radius > min_budget then
			r[ci] = min_budget
		end
	end

	return {
		topLeft = {
			radius = r[1],
			roundingAndSmoothingBudget = b[1],
		},

		topRight = {
			radius = r[2],
			roundingAndSmoothingBudget = b[2],
		},

		bottomRight = {
			radius = r[3],
			roundingAndSmoothingBudget = b[3],
		},

		bottomLeft = {
			radius = r[4],
			roundingAndSmoothingBudget = b[4],
		},
	}
end

return {
	distribute_and_normalize = distribute_and_normalize,
}
