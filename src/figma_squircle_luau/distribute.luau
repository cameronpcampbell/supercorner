--!strict

const types = require("./types")

type NormalizedCorner = types.NormalizedCorner
type NormalizedCorners = types.NormalizedCorners

type CornerName = "topLeft" | "topRight" | "bottomLeft" | "bottomRight"
type SideName = "top" | "left" | "bottom" | "right"

type Adjacent = {
	corner: CornerName,
	side: SideName,
}

type Adjacency = { Adjacent }

const ADJACENTS: { [CornerName]: Adjacency } = {
	topLeft = {
		{ corner = "topRight", side = "top" },
		{ corner = "bottomLeft", side = "left" },
	},

	topRight = {
		{ corner = "topLeft", side = "top" },
		{ corner = "bottomRight", side = "right" },
	},

	bottomLeft = {
		{ corner = "bottomRight", side = "bottom" },
		{ corner = "topLeft", side = "left" },
	},

	bottomRight = {
		{ corner = "bottomLeft", side = "bottom" },
		{ corner = "topRight", side = "right" },
	},
}

const function get_side_length(side: SideName, width: number, height: number): number
	if side == "top" or side == "bottom" then
		return width
	else
		return height
	end
end

const function get_corner_radius(corner: CornerName, radii: { [CornerName]: number }): number
	return radii[corner] or 0
end

const function distribute_and_normalize(
	width: number,
	height: number,
	top_left_radius: number,
	top_right_radius: number,
	bottom_right_radius: number,
	bottom_left_radius: number
): NormalizedCorners
	local radii: { [CornerName]: number } = {
		topLeft = top_left_radius,
		topRight = top_right_radius,
		bottomRight = bottom_right_radius,
		bottomLeft = bottom_left_radius,
	}

	local budgets: { [CornerName]: number } = {
		topLeft = -1,
		topRight = -1,
		bottomRight = -1,
		bottomLeft = -1,
	}

	local corner_names: { CornerName } = { "topLeft", "topRight", "bottomRight", "bottomLeft" }
	table.sort(corner_names, function(a, b)
		return get_corner_radius(a, radii) > get_corner_radius(b, radii)
	end)

	for _, corner_name: CornerName in corner_names do
		local radius = get_corner_radius(corner_name, radii)
		local adjacents = ADJACENTS[corner_name]
		local min_budget = math.huge

		for _, adj in adjacents do
			local adj_radius = get_corner_radius(adj.corner, radii)
			local side_length = get_side_length(adj.side, width, height)
			local budget: number

			if radius == 0 and adj_radius == 0 then
				budget = 0
			elseif budgets[adj.corner] >= 0 then
				budget = side_length - budgets[adj.corner]
			else
				budget = (radius / (radius + adj_radius)) * side_length
			end

			if budget < min_budget then
				min_budget = budget
			end
		end

		budgets[corner_name] = min_budget

		if radius > min_budget then
			radii[corner_name] = min_budget
		end
	end

	return {
		topLeft = {
			radius = radii.topLeft,
			roundingAndSmoothingBudget = budgets.topLeft,
		},

		topRight = {
			radius = radii.topRight,
			roundingAndSmoothingBudget = budgets.topRight,
		},

		bottomLeft = {
			radius = radii.bottomLeft,
			roundingAndSmoothingBudget = budgets.bottomLeft,
		},

		bottomRight = {
			radius = radii.bottomRight,
			roundingAndSmoothingBudget = budgets.bottomRight,
		},
	}
end

return {
	distribute_and_normalize = distribute_and_normalize,
}
