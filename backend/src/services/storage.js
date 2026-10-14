const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const { createClient } = require('@supabase/supabase-js');

const UPLOADS_ROOT = path.join(__dirname, '..', '..', 'uploads');
const PROOFS_DIR = path.join(UPLOADS_ROOT, 'proofs');
const ISSUES_DIR = path.join(UPLOADS_ROOT, 'issues');

// Ensure local upload directories exist
[PROOFS_DIR, ISSUES_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Supabase client initialization (if configured)
let supabase = null;
const isSupabaseConfigured = Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY);

if (isSupabaseConfigured) {
  supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
  console.log('[STORAGE] Supabase Storage client initialized');
} else {
  console.log('[STORAGE] Using local private storage (uploads/proofs)');
}

// Multer storage engine
const proofStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, PROOFS_DIR);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    const uniqueFilename = `proof_${Date.now()}_${uuidv4().substring(0, 8)}${ext}`;
    cb(null, uniqueFilename);
  }
});

const uploadProofMiddleware = multer({
  storage: proofStorage,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

/**
 * Upload file to Supabase Storage if configured
 */
async function uploadToSupabaseBucket(localFilePath, destinationFileName, bucket = 'ad-proofs') {
  if (!supabase) return null;
  try {
    const fileBuffer = fs.readFileSync(localFilePath);
    const { data, error } = await supabase.storage
      .from(bucket)
      .upload(destinationFileName, fileBuffer, {
        contentType: 'image/jpeg',
        upsert: true
      });

    if (error) {
      console.error('[SUPABASE STORAGE] Upload error:', error);
      return null;
    }
    return data.path;
  } catch (err) {
    console.error('[SUPABASE STORAGE] Exception:', err);
    return null;
  }
}

/**
 * Create a signed private URL from Supabase Storage (expires in 60 mins)
 */
async function getSupabaseSignedUrl(storagePath, bucket = 'ad-proofs', expiresInSeconds = 3600) {
  if (!supabase || !storagePath) return null;
  try {
    const { data, error } = await supabase.storage
      .from(bucket)
      .createSignedUrl(storagePath, expiresInSeconds);

    if (error) {
      console.error('[SUPABASE STORAGE] Signed URL error:', error);
      return null;
    }
    return data.signedUrl;
  } catch (err) {
    console.error('[SUPABASE STORAGE] Exception:', err);
    return null;
  }
}

/**
 * Permanently delete an image file from storage (both local and Supabase)
 */
async function deletePhysicalFile(relativePath, bucket = 'ad-proofs') {
  if (!relativePath) return false;

  // 1. Delete from Supabase bucket if configured
  if (supabase) {
    try {
      const fileName = path.basename(relativePath);
      await supabase.storage.from(bucket).remove([fileName, relativePath]);
      console.log(`[SUPABASE STORAGE] Deleted file from bucket ${bucket}: ${relativePath}`);
    } catch (err) {
      console.error('[SUPABASE STORAGE] Error deleting bucket object:', err);
    }
  }

  // 2. Delete local physical copy
  const fullPath = path.isAbsolute(relativePath)
    ? relativePath
    : path.join(__dirname, '..', '..', relativePath);

  try {
    if (fs.existsSync(fullPath)) {
      fs.unlinkSync(fullPath);
      console.log(`[STORAGE] Local physical file deleted: ${fullPath}`);
      return true;
    }
  } catch (err) {
    console.error(`[STORAGE] Error deleting file ${fullPath}:`, err);
  }
  return false;
}

/**
 * Resolve full path to an image file
 */
function resolveFilePath(relativePath) {
  if (!relativePath) return null;
  return path.isAbsolute(relativePath)
    ? relativePath
    : path.join(__dirname, '..', '..', relativePath);
}

module.exports = {
  uploadProofMiddleware,
  uploadToSupabaseBucket,
  getSupabaseSignedUrl,
  deletePhysicalFile,
  resolveFilePath,
  isSupabaseConfigured,
  PROOFS_DIR,
  ISSUES_DIR
};
