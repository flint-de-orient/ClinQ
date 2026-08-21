import mongoose from 'mongoose';

/**
 * The brands this clinic actually prescribes, and what is in them.
 *
 * Not a drug index. A licensed one (CIMS, MIMS, 1mg) is complete and
 * maintained and costs money forever; a single-doctor diabetes practice
 * prescribes from a set of perhaps eighty products, and knowing those eighty
 * exactly is worth more than knowing forty thousand approximately.
 *
 * It exists because "Gluconorm G1 500/50" reached a patient's screen. The brand
 * is glimepiride 1 mg with metformin 500 mg — its strength should read 500/1,
 * and 500/50 belongs to a different combination entirely. Nothing in the app
 * could see that, because a brand name is opaque text until something maps it
 * to a composition.
 *
 * What this is FOR is prefilling and warning, never correcting. The doctor
 * prescribes; software that silently rewrites a dose is worse than software
 * that shows an inconsistency, because the inconsistency is visible and gets
 * caught.
 */
const compositionSchema = new mongoose.Schema(
  {
    /// Generic name — "Metformin", "Glimepiride".
    ingredient: { type: String, required: true, trim: true, maxlength: 120 },
    /// Amount of that ingredient in one unit, in `unit`.
    amount: { type: Number, required: true, min: 0 },
    unit: { type: String, default: 'mg', trim: true, maxlength: 12 },
  },
  { _id: false },
);

const medicineBrandSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 160, index: true },

    /// Lower-cased and stripped of punctuation, for matching what a doctor
    /// types: "gluconormg1" matches "Gluconorm-G1" and "Gluconorm G1".
    slug: { type: String, required: true, unique: true, index: true },

    composition: { type: [compositionSchema], default: [] },

    /// The strength as it should be written on a prescription — "500/1" for a
    /// combination, "1" for a single agent. Derived from the composition on
    /// save so the two can never disagree.
    strengthLabel: { type: String, trim: true, maxlength: 60 },

    /// The unit every component shares, when they do. Null for a mixed-unit
    /// product, where a single slashed figure would be a lie.
    strengthUnit: { type: String, trim: true, maxlength: 12, default: 'mg' },

    form: { type: String, trim: true, maxlength: 40, default: 'tablet' },

    /// Free text for anything a prescriber should see — "take with food",
    /// "reduce in renal impairment".
    note: { type: String, trim: true, maxlength: 300 },

    /// Seeded rows can be replaced by a reseed; rows the clinic added by hand
    /// must not be.
    isSeed: { type: Boolean, default: false },
  },
  { timestamps: true },
);

/** "Gluconorm-G1" -> "gluconormg1". */
export function brandSlug(name) {
  return String(name ?? '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

medicineBrandSchema.pre('validate', function derive() {
  if (this.name) this.slug = brandSlug(this.name);

  const parts = this.composition ?? [];
  if (parts.length === 0) return;

  const units = [...new Set(parts.map((p) => p.unit || 'mg'))];
  if (units.length === 1) {
    this.strengthUnit = units[0];
    this.strengthLabel = parts.map((p) => p.amount).join('/');
  } else {
    // Mixed units cannot be written as one slashed figure without misleading
    // somebody, so the label carries them explicitly.
    this.strengthUnit = null;
    this.strengthLabel = parts.map((p) => `${p.amount}${p.unit}`).join(' + ');
  }
});

export const MedicineBrand = mongoose.model('MedicineBrand', medicineBrandSchema);
