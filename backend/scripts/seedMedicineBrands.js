/**
 * Seeds the brands this clinic prescribes, with what is in them.
 *
 * Diabetes and the conditions that travel with it: oral agents, insulins,
 * statins, antihypertensives and the supplements that go alongside. Indian
 * brand names, because that is what gets written on a prescription here.
 *
 * Compositions are the standard marketed strengths. They are a starting point
 * for the clinic to correct, not an authority — which is why every row is
 * marked isSeed and a row the clinic has edited by hand is never overwritten.
 *
 *   node scripts/seedMedicineBrands.js          # report
 *   node scripts/seedMedicineBrands.js --apply  # write
 */
import mongoose from 'mongoose';
import { env } from '../src/config/env.js';
import { MedicineBrand, brandSlug } from '../src/models/MedicineBrand.js';

const apply = process.argv.includes('--apply');

const mg = (ingredient, amount) => ({ ingredient, amount, unit: 'mg' });
const mcg = (ingredient, amount) => ({ ingredient, amount, unit: 'mcg' });
const iuml = (ingredient) => ({ ingredient, amount: 100, unit: 'IU/mL' });

const BRANDS = [
  // ---- Biguanides
  { name: 'Glycomet 500', composition: [mg('Metformin', 500)], note: 'With or after food.' },
  { name: 'Glycomet 850', composition: [mg('Metformin', 850)], note: 'With or after food.' },
  { name: 'Glycomet SR 1000', composition: [mg('Metformin', 1000)], note: 'Sustained release. With dinner.' },
  { name: 'Obimet SR 500', composition: [mg('Metformin', 500)] },
  { name: 'Gluconorm 500', composition: [mg('Metformin', 500)] },

  // ---- Sulfonylurea + metformin. The family the 500/50 came from.
  { name: 'Gluconorm-G1', composition: [mg('Metformin', 500), mg('Glimepiride', 1)], note: 'Never skip a meal on a sulfonylurea.' },
  { name: 'Gluconorm-G2', composition: [mg('Metformin', 500), mg('Glimepiride', 2)], note: 'Never skip a meal on a sulfonylurea.' },
  { name: 'Glycomet-GP1', composition: [mg('Metformin', 500), mg('Glimepiride', 1)] },
  { name: 'Glycomet-GP2', composition: [mg('Metformin', 500), mg('Glimepiride', 2)] },
  { name: 'Amaryl M1', composition: [mg('Metformin', 500), mg('Glimepiride', 1)] },
  { name: 'Amaryl M2', composition: [mg('Metformin', 500), mg('Glimepiride', 2)] },

  // ---- Sulfonylureas alone
  { name: 'Amaryl 1', composition: [mg('Glimepiride', 1)] },
  { name: 'Amaryl 2', composition: [mg('Glimepiride', 2)] },
  { name: 'Glimestar 1', composition: [mg('Glimepiride', 1)] },
  { name: 'Diamicron MR 60', composition: [mg('Gliclazide', 60)] },

  // ---- DPP-4 inhibitors, alone and with metformin
  { name: 'Januvia 100', composition: [mg('Sitagliptin', 100)] },
  { name: 'Janumet 50/500', composition: [mg('Sitagliptin', 50), mg('Metformin', 500)] },
  { name: 'Janumet 50/1000', composition: [mg('Sitagliptin', 50), mg('Metformin', 1000)] },
  { name: 'Galvus 50', composition: [mg('Vildagliptin', 50)] },
  // The combination that "500/50" actually belongs to.
  { name: 'Galvus Met 50/500', composition: [mg('Vildagliptin', 50), mg('Metformin', 500)] },
  { name: 'Zomelis Met 50/500', composition: [mg('Vildagliptin', 50), mg('Metformin', 500)] },
  { name: 'Istamet 50/500', composition: [mg('Sitagliptin', 50), mg('Metformin', 500)] },
  { name: 'Teneligliptin 20', composition: [mg('Teneligliptin', 20)] },
  { name: 'Tenepride 20', composition: [mg('Teneligliptin', 20)] },

  // ---- SGLT2 inhibitors
  { name: 'Forxiga 10', composition: [mg('Dapagliflozin', 10)], note: 'Keep fluids up unless the doctor has restricted them.' },
  { name: 'Jardiance 10', composition: [mg('Empagliflozin', 10)] },
  { name: 'Jardiance 25', composition: [mg('Empagliflozin', 25)] },
  { name: 'Dapanorm 10', composition: [mg('Dapagliflozin', 10)] },
  { name: 'Dapa-Met 10/500', composition: [mg('Dapagliflozin', 10), mg('Metformin', 500)] },

  // ---- Insulins. Units, not milligrams — the reason the strength formatter
  // refuses to assume mg for a bare number.
  { name: 'Lantus', composition: [iuml('Insulin glargine')], form: 'injection', note: 'Once daily, same time each day.' },
  { name: 'Basalog', composition: [iuml('Insulin glargine')], form: 'injection' },
  { name: 'Huminsulin 30/70', composition: [iuml('Insulin human premix 30/70')], form: 'injection' },
  { name: 'Novomix 30', composition: [iuml('Insulin aspart premix 30')], form: 'injection' },
  { name: 'Tresiba', composition: [iuml('Insulin degludec')], form: 'injection' },

  // ---- Statins and antiplatelets
  { name: 'Atorva 10', composition: [mg('Atorvastatin', 10)], note: 'At night.' },
  { name: 'Atorva 20', composition: [mg('Atorvastatin', 20)], note: 'At night.' },
  { name: 'Rosuvas 10', composition: [mg('Rosuvastatin', 10)] },
  { name: 'Rosuvas 20', composition: [mg('Rosuvastatin', 20)] },
  { name: 'Ecosprin 75', composition: [mg('Aspirin', 75)], note: 'After food.' },
  { name: 'Ecosprin-AV 75/10', composition: [mg('Aspirin', 75), mg('Atorvastatin', 10)] },

  // ---- Blood pressure
  { name: 'Telma 40', composition: [mg('Telmisartan', 40)] },
  { name: 'Telma 80', composition: [mg('Telmisartan', 80)] },
  { name: 'Telma-H 40/12.5', composition: [mg('Telmisartan', 40), mg('Hydrochlorothiazide', 12.5)] },
  { name: 'Amlong 5', composition: [mg('Amlodipine', 5)] },
  { name: 'Losar 50', composition: [mg('Losartan', 50)] },
  { name: 'Envas 5', composition: [mg('Enalapril', 5)] },
  { name: 'Met XL 25', composition: [mg('Metoprolol', 25)] },

  // ---- Thyroid
  { name: 'Thyronorm 25', composition: [mcg('Levothyroxine', 25)], note: 'Empty stomach, 30 minutes before breakfast.' },
  { name: 'Thyronorm 50', composition: [mcg('Levothyroxine', 50)], note: 'Empty stomach, 30 minutes before breakfast.' },
  { name: 'Eltroxin 100', composition: [mcg('Levothyroxine', 100)] },

  // ---- Supplements prescribed alongside
  { name: 'Nurokind Plus', composition: [mcg('Methylcobalamin', 1500)], note: 'For metformin-associated B12 deficiency.' },
  { name: 'Uprise D3 60K', composition: [{ ingredient: 'Cholecalciferol', amount: 60000, unit: 'IU' }], note: 'Weekly, with food.' },
  { name: 'Shelcal 500', composition: [mg('Calcium carbonate', 500)] },
  { name: 'Pan 40', composition: [mg('Pantoprazole', 40)], note: 'Before breakfast.' },
];

async function main() {
  await mongoose.connect(env.MONGODB_URI);

  let created = 0;
  let refreshed = 0;
  let skipped = 0;

  for (const b of BRANDS) {
    const slug = brandSlug(b.name);
    const existing = await MedicineBrand.findOne({ slug }).lean();

    // A row the clinic edited by hand outranks the seed. This script must never
    // undo somebody's correction.
    if (existing && existing.isSeed === false) {
      skipped += 1;
      console.log(`${b.name.padEnd(24)} skipped — edited by the clinic`);
      continue;
    }

    if (!apply) {
      console.log(`${b.name.padEnd(24)} ${existing ? 'would refresh' : 'would create'}`);
      if (existing) refreshed += 1;
      else created += 1;
      continue;
    }

    if (existing) {
      await MedicineBrand.findOneAndUpdate({ slug }, { ...b, isSeed: true }, { new: true });
      refreshed += 1;
    } else {
      await MedicineBrand.create({ ...b, isSeed: true });
      created += 1;
    }
  }

  console.log(`\n${BRANDS.length} brands — ${created} new, ${refreshed} refreshed, ${skipped} left alone.`);
  if (!apply) console.log('Nothing written. Re-run with --apply.');
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => mongoose.disconnect());
