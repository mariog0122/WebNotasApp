export const COMMERCIAL_PLANS = Object.freeze([
  Object.freeze({
    code: 'institutional_500',
    name: 'Plan Institucional 500',
    monthlyPrice: 89,
    annualPrice: 890,
    maxStudents: 500,
    trialDays: 15,
    implementationFee: 350,
  }),
  Object.freeze({
    code: 'institutional_1000',
    name: 'Plan Institucional 1000',
    monthlyPrice: 129,
    annualPrice: 1290,
    maxStudents: 1000,
    trialDays: 15,
    implementationFee: 350,
  }),
  Object.freeze({
    code: 'institutional_2000',
    name: 'Plan Institucional 2000',
    monthlyPrice: 179,
    annualPrice: 1790,
    maxStudents: 2000,
    trialDays: 15,
    implementationFee: 350,
  }),
])

export const getPlan = (code) => COMMERCIAL_PLANS.find((plan) => plan.code === code) || null

export const getPlanPrice = (code, cycle = 'monthly') => {
  const plan = getPlan(code)
  if (!plan) return null
  return cycle === 'yearly' ? plan.annualPrice : plan.monthlyPrice
}
