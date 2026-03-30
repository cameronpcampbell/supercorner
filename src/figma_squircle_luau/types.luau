--!strict

export type MoveToOp = {
	type: "M",
	x: number,
	y: number,
}

export type LineToOp = {
	type: "L",
	x: number,
	y: number,
}

export type CubicBezierOp = {
	type: "c",
	dx1: number,
	dy1: number,
	dx2: number,
	dy2: number,
	dx: number,
	dy: number,
}

export type ArcOp = {
	type: "a",
	rx: number,
	ry: number,
	rotation: number,
	largeArc: number,
	sweep: number,
	dx: number,
	dy: number,
}

export type ClosePathOp = {
	type: "Z",
}

export type SvgOp = MoveToOp | LineToOp | CubicBezierOp | ArcOp | ClosePathOp

export type FigmaSquircleParams = {
	width: number,
	height: number,
	cornerRadius: number?,
	topLeftCornerRadius: number?,
	topRightCornerRadius: number?,
	bottomRightCornerRadius: number?,
	bottomLeftCornerRadius: number?,
	cornerSmoothing: number,
	preserveSmoothing: boolean?,
}

export type CornerPathParams = {
	a: number,
	b: number,
	c: number,
	d: number,
	p: number,
	cornerRadius: number,
	arcSectionLength: number,
}

export type CornerParams = {
	cornerRadius: number,
	cornerSmoothing: number,
	preserveSmoothing: boolean,
	roundingAndSmoothingBudget: number,
}

export type NormalizedCorner = {
	radius: number,
	roundingAndSmoothingBudget: number,
}

export type NormalizedCorners = {
	topLeft: NormalizedCorner,
	topRight: NormalizedCorner,
	bottomLeft: NormalizedCorner,
	bottomRight: NormalizedCorner,
}

return nil
