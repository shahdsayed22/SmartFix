import mongoose from 'mongoose';

// A labelled NLP training sample, collected from real reported issues.
// Grows a corpus (text → category/urgency) that scripts/export-nlp-samples.mjs
// turns into JSONL for retraining the Arabic classifier. `corrected` flags the
// high-value rows where the customer overrode the AI's suggestion.
const TrainingSampleSchema = new mongoose.Schema({
  text: { type: String, required: true, trim: true },
  category: {
    type: String,
    required: true,
    enum: ['plumbing', 'electrical', 'carpentry', 'painting', 'hvac', 'cleaning', 'appliance_repair', 'welding', 'tiling'],
  },
  urgency: {
    type: String,
    enum: ['low', 'medium', 'high', 'emergency'],
    default: 'medium',
  },
  aiSuggestedCategory: { type: String, default: '' },
  aiMethod: { type: String, default: '' },
  corrected: { type: Boolean, default: false },
  source: { type: String, default: 'report' },
  createdAt: { type: Date, default: Date.now },
});

TrainingSampleSchema.index({ createdAt: -1 });
TrainingSampleSchema.index({ category: 1 });

export default mongoose.models.TrainingSample || mongoose.model('TrainingSample', TrainingSampleSchema);
