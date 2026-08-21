/**
 * Finds medicine strengths that disagree with what the brand actually contains,
 * and — for the live medication tracker only — corrects them.
 *
 * This is the cleanup for records written before the brand list existed: the
 * "Gluconorm G1 500/50" a patient is looking at right now. The prescribing
 * check catches new mistakes; nothing catches the ones already saved.
 *
 * TWO STORES, TREATED DIFFERENTLY, AND THE DIFFERENCE IS THE POINT:
 *
 *   Medication — what the patient is currently taking, what their Medicines tab
 *   shows and their reminders fire against. A wrong strength here is a live
 *   error in front of a patient every day. Corrected with --apply.
 *
 *   Prescription.items — what the doctor wrote on a given date. That is a
 *   record of an act, not a description of the present. Editing it would
 *   falsify the record: it would then show the doctor prescribing something
 *   they did not write. Reported, never touched. If an issued prescription is
 *   wrong, the answer is a new prescription, which is also how it works on
 *   paper.
 *
 * Reports by default; corrects the tracker only with --apply. Read the report
 * before running it — every change is a dose in front of a patient, and a
 * human should have seen the list.
 *
 *   node scripts/auditMedicineStrengths.js
 *   node scripts/auditMedicineStrengths.js --apply
 *   node scripts/auditMedicineStrengths.js --apply --patient <userId>
 */
import mongoose from 'mongoose';
import { env } from '../src/config/env.js';
import { Medication } from '../src/models/Medication.js';
import { Prescription } from '../src/models/Prescription.js';
import { User } from '../src/models/User.js';
import { MedicineBrand, brandSlug } from '../src/models/MedicineBrand.js';

const apply = process.argv.includes('--apply');
const onlyPatient = (() => {
  const i = process.argv.indexOf('--patient');
  return i !== -1 ? process.argv[i + 1] : null;
})();

/// Just the figures, so "500/1" and "500/1 mg" are the same strength and only a
/// real disagreement is reported.
const figures = (v) => String(v ?? '').replace(/[^0-9./]/g, '');

/// The strength a brand should carry, unit included.
function expected(brand) {
  if (!brand?.strengthLabel) return null;
  return brand.strengthUnit ? `${brand.strengthLabel} ${brand.strengthUnit}` : brand.strengthLabel;
}

async function main() {
  await mongoose.connect(env.MONGODB_URI);

  const brands = await MedicineBrand.find().lean();
  if (brands.length === 0) {
    console.log('No brands recorded. Run scripts/seedMedicineBrands.js --apply first.');
    return;
  }
  const bySlug = new Map(brands.map((b) => [b.slug, b]));
  console.log(`${brands.length} brands on file.\n`);

  const patientFilter = onlyPatient ? { patient: onlyPatient } : {};

  // ---- The live tracker: correctable -------------------------------------
  const meds = await Medication.find({ ...patientFilter, isActive: true })
    .populate('patient', 'name')
    .lean();

  let wrong = 0;
  let fixed = 0;
  let missing = 0;

  console.log('CURRENT MEDICATIONS');
  for (const m of meds) {
    const brand = bySlug.get(brandSlug(m.name));
    if (!brand) continue;
    const want = expected(brand);
    if (!want) continue;

    const has = (m.strength ?? '').trim();
    if (has.length === 0) {
      missing += 1;
      console.log(
        `  ${(m.patient?.name ?? '?').padEnd(16)} ${m.name.padEnd(22)} (no strength) -> ${want}`,
      );
      if (apply) {
        await Medication.updateOne({ _id: m._id }, { strength: want });
        fixed += 1;
      }
      continue;
    }
    if (figures(has) === figures(want)) continue;

    wrong += 1;
    console.log(
      `  ${(m.patient?.name ?? '?').padEnd(16)} ${m.name.padEnd(22)} ${has} -> ${want}` +
        `   [${(brand.composition ?? []).map((c) => `${c.ingredient} ${c.amount}${c.unit}`).join(' + ')}]`,
    );
    if (apply) {
      await Medication.updateOne({ _id: m._id }, { strength: want });
      fixed += 1;
    }
  }
  if (wrong === 0 && missing === 0) console.log('  nothing to correct');

  // ---- Issued prescriptions: reported only -------------------------------
  const rxFilter = onlyPatient ? { patient: onlyPatient } : {};
  const prescriptions = await Prescription.find(rxFilter)
    .populate('patient', 'name')
    .select('patient items issuedOn')
    .lean();

  let rxWrong = 0;
  console.log('\nISSUED PRESCRIPTIONS  (reported only — a record of what was written)');
  for (const rx of prescriptions) {
    for (const it of rx.items ?? []) {
      const brand = bySlug.get(brandSlug(it.name));
      const want = expected(brand);
      if (!want) continue;
      const has = (it.strength ?? '').trim();
      if (has.length === 0 || figures(has) === figures(want)) continue;

      rxWrong += 1;
      const on = rx.issuedOn ? new Date(rx.issuedOn).toISOString().slice(0, 10) : '?';
      console.log(
        `  ${on}  ${(rx.patient?.name ?? '?').padEnd(16)} ${it.name.padEnd(22)} ${has} (records say ${want})`,
      );
    }
  }
  if (rxWrong === 0) console.log('  none disagree');

  // ---- Summary -----------------------------------------------------------
  console.log(
    `\n${meds.length} active medications — ${wrong} disagree, ${missing} carry no strength.`,
  );
  if (apply) {
    console.log(`${fixed} corrected in the tracker.`);
  } else if (wrong + missing > 0) {
    console.log('Nothing written. Re-run with --apply once the list above reads correctly.');
  }
  if (rxWrong > 0) {
    console.log(
      `\n${rxWrong} issued prescription line(s) disagree and were NOT changed. An issued\n` +
        'prescription records what the doctor wrote; if one is wrong, the fix is to\n' +
        'issue a new prescription, exactly as it would be on paper.',
    );
  }
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => mongoose.disconnect());
