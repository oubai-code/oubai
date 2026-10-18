-- ==============================================================================
-- Supabase Schema for Proyecto TNR CDMX
-- Tables: products, animals, albums, album_media, gallery (legacy compatibility)
-- Run this in the Supabase SQL Editor to apply all database updates.
-- ==============================================================================

-- 1. Ensure public.admin_users exists for authorization
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.admin_users ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.admin_users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- Secure Admin check function (Security Definer to prevent recursive RLS)
DROP FUNCTION IF EXISTS public.is_admin(UUID) CASCADE;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE admin_users.user_id::text = auth.uid()::text
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view admin_users" ON public.admin_users;
CREATE POLICY "Admins can view admin_users"
  ON public.admin_users FOR SELECT
  TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can insert admin_users" ON public.admin_users;
CREATE POLICY "Admins can insert admin_users"
  ON public.admin_users FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete admin_users" ON public.admin_users;
CREATE POLICY "Admins can delete admin_users"
  ON public.admin_users FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- ==============================================================================
-- 2. ANIMALS TABLE (Updated with Type, Gender, Age, and Manual Display Order)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.animals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  image_url TEXT NOT NULL,
  status TEXT DEFAULT 'available',
  animal_type TEXT DEFAULT 'dog',
  gender TEXT DEFAULT 'female',
  age_value NUMERIC DEFAULT 1,
  age_unit TEXT DEFAULT 'years',
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Upgrade existing animals table if columns are missing
ALTER TABLE public.animals ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'available';
ALTER TABLE public.animals ADD COLUMN IF NOT EXISTS animal_type TEXT DEFAULT 'dog';
ALTER TABLE public.animals ADD COLUMN IF NOT EXISTS gender TEXT DEFAULT 'female';
ALTER TABLE public.animals ADD COLUMN IF NOT EXISTS age_value NUMERIC DEFAULT 1;
ALTER TABLE public.animals ADD COLUMN IF NOT EXISTS age_unit TEXT DEFAULT 'years';
ALTER TABLE public.animals ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0;

ALTER TABLE public.animals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view animals" ON public.animals;
DROP POLICY IF EXISTS "Admins can insert animals" ON public.animals;
DROP POLICY IF EXISTS "Admins can update animals" ON public.animals;
DROP POLICY IF EXISTS "Admins can delete animals" ON public.animals;

-- Allow public read access to animals
CREATE POLICY "Public can view animals"
  ON public.animals FOR SELECT
  TO public
  USING (true);

-- Allow authorized admins to manage animals
CREATE POLICY "Admins can insert animals"
  ON public.animals FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can update animals"
  ON public.animals FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can delete animals"
  ON public.animals FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

-- ==============================================================================
-- 3. PRODUCTS TABLE (Online Pet Shop with Manual Display Order)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  price TEXT NOT NULL,
  image_url TEXT NOT NULL,
  display_order INT DEFAULT 0,
  stock_quantity INT DEFAULT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS stock_quantity INT DEFAULT NULL;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view products" ON public.products;
DROP POLICY IF EXISTS "Admins can insert products" ON public.products;
DROP POLICY IF EXISTS "Admins can update products" ON public.products;
DROP POLICY IF EXISTS "Admins can delete products" ON public.products;

CREATE POLICY "Public can view products"
  ON public.products FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Admins can insert products"
  ON public.products FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can update products"
  ON public.products FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can delete products"
  ON public.products FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

-- ==============================================================================
-- 4. ALBUMS TABLE (Gallery Albums with Manual Display Order)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.albums (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.albums ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0;

ALTER TABLE public.albums ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view albums" ON public.albums;
DROP POLICY IF EXISTS "Admins can insert albums" ON public.albums;
DROP POLICY IF EXISTS "Admins can update albums" ON public.albums;
DROP POLICY IF EXISTS "Admins can delete albums" ON public.albums;

CREATE POLICY "Public can view albums"
  ON public.albums FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Admins can insert albums"
  ON public.albums FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can update albums"
  ON public.albums FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can delete albums"
  ON public.albums FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

-- ==============================================================================
-- 5. ALBUM_MEDIA TABLE (Media items inside albums: Images & Videos)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.album_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id UUID NOT NULL REFERENCES public.albums(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL DEFAULT 'image' CHECK (media_type IN ('image', 'video')),
  media_url TEXT NOT NULL,
  caption TEXT DEFAULT '',
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.album_media ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0;

ALTER TABLE public.album_media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view album_media" ON public.album_media;
DROP POLICY IF EXISTS "Admins can insert album_media" ON public.album_media;
DROP POLICY IF EXISTS "Admins can update album_media" ON public.album_media;
DROP POLICY IF EXISTS "Admins can delete album_media" ON public.album_media;

CREATE POLICY "Public can view album_media"
  ON public.album_media FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Admins can insert album_media"
  ON public.album_media FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can update album_media"
  ON public.album_media FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can delete album_media"
  ON public.album_media FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

-- ==============================================================================
-- 6. LEGACY GALLERY TABLE (Preserved for backwards compatibility)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.gallery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  image_url TEXT NOT NULL,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.gallery ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0;

ALTER TABLE public.gallery ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view gallery" ON public.gallery;
DROP POLICY IF EXISTS "Admins can insert gallery photos" ON public.gallery;
DROP POLICY IF EXISTS "Admins can update gallery photos" ON public.gallery;
DROP POLICY IF EXISTS "Admins can delete gallery photos" ON public.gallery;

CREATE POLICY "Public can view gallery"
  ON public.gallery FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Admins can insert gallery photos"
  ON public.gallery FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can update gallery photos"
  ON public.gallery FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can delete gallery photos"
  ON public.gallery FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

-- ==============================================================================
-- 7. SAFE DATA MIGRATION: Migrate existing gallery photos into Albums
-- ==============================================================================
DO $$
DECLARE
  default_album_id UUID;
  rec RECORD;
  ord INT := 0;
BEGIN
  -- If public.gallery has records and public.albums has no records yet, create a default album
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'gallery') THEN
    IF NOT EXISTS (SELECT 1 FROM public.albums) AND EXISTS (SELECT 1 FROM public.gallery) THEN
      INSERT INTO public.albums (title, description, display_order)
      VALUES (
        'Featured Moments & Rescue Activities',
        'Moments captured during rescue missions, sterilizations, and successful adoptions.',
        1
      )
      RETURNING id INTO default_album_id;

      FOR rec IN SELECT * FROM public.gallery ORDER BY created_at ASC LOOP
        ord := ord + 1;
        INSERT INTO public.album_media (album_id, media_type, media_url, caption, display_order, created_at)
        VALUES (default_album_id, 'image', rec.image_url, rec.title, ord, rec.created_at);
      END LOOP;
    END IF;
  END IF;
END $$;

-- ==============================================================================
-- 8. ORDERS TABLE (Multi-Product Online Pet Shop Orders)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_no TEXT UNIQUE NOT NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  customer_email TEXT DEFAULT '',
  delivery_address TEXT NOT NULL,
  city TEXT NOT NULL,
  notes TEXT DEFAULT '',
  total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending',
  stock_deducted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Upgrade existing orders table if columns/constraints need updating
ALTER TABLE public.orders ALTER COLUMN customer_email DROP NOT NULL;
ALTER TABLE public.orders ALTER COLUMN customer_email SET DEFAULT '';
ALTER TABLE public.orders ALTER COLUMN notes DROP NOT NULL;
ALTER TABLE public.orders ALTER COLUMN notes SET DEFAULT '';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS stock_deducted BOOLEAN DEFAULT FALSE;

-- Ensure non-negative stock constraint on products
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_products_stock_non_negative') THEN
    ALTER TABLE public.products ADD CONSTRAINT chk_products_stock_non_negative CHECK (stock_quantity IS NULL OR stock_quantity >= 0);
  END IF;
END $$;

-- DROP LEGACY TRIGGER (Orders start as pending WITHOUT deducting inventory)
DROP TRIGGER IF EXISTS trg_process_order_inventory ON public.orders;
DROP FUNCTION IF EXISTS public.process_order_inventory();

-- Server-Side Inventory Validation & Atomic Deduction RPC Functions
CREATE OR REPLACE FUNCTION public.update_order_status(
  p_order_id UUID,
  p_new_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_item RECORD;
  v_items_arr JSONB;
  v_prod_id_text TEXT;
  v_prod_id UUID;
  v_qty INT;
  v_product RECORD;
  v_normalized_status TEXT;
BEGIN
  -- 1. Check admin authorization
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: only authorized administrators can update order status.';
  END IF;

  v_normalized_status := LOWER(TRIM(p_new_status));
  IF v_normalized_status NOT IN ('pending', 'confirmed', 'delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid order status "%". Allowed values: pending, confirmed, delivered, cancelled.', p_new_status;
  END IF;

  -- 2. Lock target order row FOR UPDATE to prevent concurrent status updates
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order with ID "%" not found.', p_order_id;
  END IF;

  -- 3. Transition to 'delivered' -> Deduct stock atomically
  IF v_normalized_status = 'delivered' THEN
    -- Never deduct stock twice if order was already delivered or stock was previously deducted
    IF v_order.stock_deducted IS TRUE OR LOWER(COALESCE(v_order.status, '')) = 'delivered' THEN
      UPDATE public.orders
      SET status = 'delivered',
          stock_deducted = TRUE
      WHERE id = p_order_id;

      RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'status', 'delivered',
        'stock_deducted', true,
        'already_deducted', true,
        'message', 'Order marked as delivered (stock was already deducted).'
      );
    END IF;

    -- Normalize items JSONB array
    IF v_order.items IS NOT NULL THEN
      IF jsonb_typeof(v_order.items) = 'array' THEN
        v_items_arr := v_order.items;
      ELSIF jsonb_typeof(v_order.items) = 'string' THEN
        BEGIN
          v_items_arr := (v_order.items #>> '{}')::jsonb;
        EXCEPTION WHEN OTHERS THEN
          v_items_arr := '[]'::jsonb;
        END;
      ELSE
        v_items_arr := '[]'::jsonb;
      END IF;

      IF jsonb_typeof(v_items_arr) = 'array' THEN
        -- Pass 1: Acquire row locks FOR UPDATE on all products and verify stock availability
        FOR v_item IN SELECT * FROM jsonb_to_recordset(v_items_arr) AS x(product_id TEXT, id TEXT, quantity INT, product_name TEXT)
        LOOP
          v_prod_id_text := COALESCE(v_item.product_id, v_item.id);
          v_qty := COALESCE(v_item.quantity, 1);

          -- Only check tracked products with valid UUIDs
          IF v_prod_id_text IS NOT NULL AND v_prod_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND v_qty > 0 THEN
            v_prod_id := v_prod_id_text::UUID;

            SELECT id, name, stock_quantity INTO v_product
            FROM public.products
            WHERE id = v_prod_id
            FOR UPDATE;

            IF FOUND THEN
              IF v_product.stock_quantity IS NOT NULL THEN
                IF v_product.stock_quantity < v_qty THEN
                  RAISE EXCEPTION 'Insufficient stock for product "%": only % unit(s) available in stock, but % requested.',
                    COALESCE(v_product.name, v_item.product_name, 'Product'),
                    v_product.stock_quantity,
                    v_qty;
                END IF;
              END IF;
            END IF;
          END IF;
        END LOOP;

        -- Pass 2: Deduct quantities from products atomically
        FOR v_item IN SELECT * FROM jsonb_to_recordset(v_items_arr) AS x(product_id TEXT, id TEXT, quantity INT, product_name TEXT)
        LOOP
          v_prod_id_text := COALESCE(v_item.product_id, v_item.id);
          v_qty := COALESCE(v_item.quantity, 1);

          IF v_prod_id_text IS NOT NULL AND v_prod_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND v_qty > 0 THEN
            v_prod_id := v_prod_id_text::UUID;

            UPDATE public.products
            SET stock_quantity = stock_quantity - v_qty
            WHERE id = v_prod_id AND stock_quantity IS NOT NULL;
          END IF;
        END LOOP;
      END IF;
    END IF;

    -- Update order status and record stock deduction
    UPDATE public.orders
    SET status = 'delivered',
        stock_deducted = TRUE
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'order_id', p_order_id,
      'status', 'delivered',
      'stock_deducted', true,
      'already_deducted', false,
      'message', 'Order delivered successfully and product stock deducted.'
    );

  -- 4. Transition to pending, confirmed, or cancelled
  ELSE
    UPDATE public.orders
    SET status = v_normalized_status
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'order_id', p_order_id,
      'status', v_normalized_status,
      'stock_deducted', COALESCE(v_order.stock_deducted, false),
      'message', 'Order status updated to ' || v_normalized_status
    );
  END IF;
END;
$$;

-- Helper RPC deliver_order for direct delivery calls
CREATE OR REPLACE FUNCTION public.deliver_order(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.update_order_status(p_order_id, 'delivered');
END;
$$;

-- Grant permissions to authenticated admins
GRANT EXECUTE ON FUNCTION public.update_order_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deliver_order(UUID) TO authenticated;

CREATE INDEX IF NOT EXISTS idx_orders_reference_no ON public.orders(reference_no);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can insert orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can view orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can update orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can delete orders" ON public.orders;

-- Anyone can submit an order (Guest checkout supported)
CREATE POLICY "Public can insert orders"
  ON public.orders FOR INSERT
  TO public
  WITH CHECK (true);

-- Only authorized admin users can view, update, or delete customer orders
CREATE POLICY "Admins can view orders"
  ON public.orders FOR SELECT
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "Admins can update orders"
  ON public.orders FOR UPDATE
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "Admins can delete orders"
  ON public.orders FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- ==============================================================================
-- 9. ADOPTION_REQUESTS TABLE (Multi-Animal Adoption Applications)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.adoption_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_no TEXT UNIQUE NOT NULL,
  applicant_name TEXT NOT NULL,
  applicant_phone TEXT NOT NULL,
  applicant_email TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  housing_type TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  animals JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_adoption_requests_reference_no ON public.adoption_requests(reference_no);
CREATE INDEX IF NOT EXISTS idx_adoption_requests_status ON public.adoption_requests(status);
CREATE INDEX IF NOT EXISTS idx_adoption_requests_created_at ON public.adoption_requests(created_at DESC);

ALTER TABLE public.adoption_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can insert adoption_requests" ON public.adoption_requests;
DROP POLICY IF EXISTS "Admins can view adoption_requests" ON public.adoption_requests;
DROP POLICY IF EXISTS "Admins can update adoption_requests" ON public.adoption_requests;
DROP POLICY IF EXISTS "Admins can delete adoption_requests" ON public.adoption_requests;

-- Anyone can submit an adoption application
CREATE POLICY "Public can insert adoption_requests"
  ON public.adoption_requests FOR INSERT
  TO public
  WITH CHECK (true);

-- Only authorized admin users can view, review, or manage adoption applications
CREATE POLICY "Admins can view adoption_requests"
  ON public.adoption_requests FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can update adoption_requests"
  ON public.adoption_requests FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

CREATE POLICY "Admins can delete adoption_requests"
  ON public.adoption_requests FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE admin_users.user_id = auth.uid())
  );

-- ==============================================================================
-- 10. SUPABASE STORAGE POLICIES (animal-images bucket)
-- ==============================================================================
-- Ensure the public animal-images storage bucket exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('animal-images', 'animal-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow anyone (public/anon) to read and view images/media in animal-images
DROP POLICY IF EXISTS "Public can view animal images" ON storage.objects;
CREATE POLICY "Public can view animal images"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'animal-images');

-- Only authorized administrators can upload new media files
DROP POLICY IF EXISTS "Admins can upload animal images" ON storage.objects;
CREATE POLICY "Admins can upload animal images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'animal-images' AND public.is_admin()
  );

-- Only authorized administrators can update/replace media files
DROP POLICY IF EXISTS "Admins can update animal images" ON storage.objects;
CREATE POLICY "Admins can update animal images"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'animal-images' AND public.is_admin()
  );

-- Only authorized administrators can delete media files
DROP POLICY IF EXISTS "Admins can delete animal images" ON storage.objects;
CREATE POLICY "Admins can delete animal images"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'animal-images' AND public.is_admin()
  );

-- ==============================================================================
-- 11. RELOAD SUPABASE POSTGREST SCHEMA CACHE
-- ==============================================================================
NOTIFY pgrst, 'reload schema';


