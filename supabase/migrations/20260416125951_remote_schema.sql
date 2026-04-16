drop extension if exists "pg_net";


  create table "public"."categories" (
    "id" uuid not null default gen_random_uuid(),
    "partnership_id" uuid not null,
    "name" text not null,
    "sort_order" integer not null default 0
      );


alter table "public"."categories" enable row level security;


  create table "public"."encryption_keys" (
    "id" uuid not null default gen_random_uuid(),
    "partnership_id" uuid not null,
    "user_id" uuid not null,
    "wrapped_key" text not null,
    "key_salt" text not null,
    "key_nonce" text not null,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."encryption_keys" enable row level security;


  create table "public"."expenses" (
    "id" uuid not null default gen_random_uuid(),
    "partnership_id" uuid not null,
    "paid_by" uuid not null,
    "date" date not null,
    "created_at" timestamp with time zone not null default now(),
    "encrypted_data" text not null
      );


alter table "public"."expenses" enable row level security;


  create table "public"."partnerships" (
    "id" uuid not null default gen_random_uuid(),
    "user1_id" uuid not null,
    "user2_id" uuid,
    "status" text not null default 'pending'::text,
    "created_at" timestamp with time zone not null default now(),
    "user1_ecdh_pub" text,
    "user2_ecdh_pub" text,
    "wrapped_partnership_key" text
      );


alter table "public"."partnerships" enable row level security;


  create table "public"."profiles" (
    "id" uuid not null,
    "display_name" text not null,
    "icon_id" integer not null default 1,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."profiles" enable row level security;

CREATE UNIQUE INDEX categories_pkey ON public.categories USING btree (id);

CREATE UNIQUE INDEX encryption_keys_partnership_id_user_id_key ON public.encryption_keys USING btree (partnership_id, user_id);

CREATE UNIQUE INDEX encryption_keys_pkey ON public.encryption_keys USING btree (id);

CREATE UNIQUE INDEX expenses_pkey ON public.expenses USING btree (id);

CREATE UNIQUE INDEX partnerships_pkey ON public.partnerships USING btree (id);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

alter table "public"."categories" add constraint "categories_pkey" PRIMARY KEY using index "categories_pkey";

alter table "public"."encryption_keys" add constraint "encryption_keys_pkey" PRIMARY KEY using index "encryption_keys_pkey";

alter table "public"."expenses" add constraint "expenses_pkey" PRIMARY KEY using index "expenses_pkey";

alter table "public"."partnerships" add constraint "partnerships_pkey" PRIMARY KEY using index "partnerships_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."categories" add constraint "categories_partnership_id_fkey" FOREIGN KEY (partnership_id) REFERENCES public.partnerships(id) ON DELETE CASCADE not valid;

alter table "public"."categories" validate constraint "categories_partnership_id_fkey";

alter table "public"."encryption_keys" add constraint "encryption_keys_partnership_id_fkey" FOREIGN KEY (partnership_id) REFERENCES public.partnerships(id) ON DELETE CASCADE not valid;

alter table "public"."encryption_keys" validate constraint "encryption_keys_partnership_id_fkey";

alter table "public"."encryption_keys" add constraint "encryption_keys_partnership_id_user_id_key" UNIQUE using index "encryption_keys_partnership_id_user_id_key";

alter table "public"."encryption_keys" add constraint "encryption_keys_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."encryption_keys" validate constraint "encryption_keys_user_id_fkey";

alter table "public"."expenses" add constraint "expenses_paid_by_fkey" FOREIGN KEY (paid_by) REFERENCES public.profiles(id) not valid;

alter table "public"."expenses" validate constraint "expenses_paid_by_fkey";

alter table "public"."expenses" add constraint "expenses_partnership_id_fkey" FOREIGN KEY (partnership_id) REFERENCES public.partnerships(id) ON DELETE CASCADE not valid;

alter table "public"."expenses" validate constraint "expenses_partnership_id_fkey";

alter table "public"."partnerships" add constraint "partnerships_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'archived'::text]))) not valid;

alter table "public"."partnerships" validate constraint "partnerships_status_check";

alter table "public"."partnerships" add constraint "partnerships_user1_id_fkey" FOREIGN KEY (user1_id) REFERENCES public.profiles(id) not valid;

alter table "public"."partnerships" validate constraint "partnerships_user1_id_fkey";

alter table "public"."partnerships" add constraint "partnerships_user2_id_fkey" FOREIGN KEY (user2_id) REFERENCES public.profiles(id) not valid;

alter table "public"."partnerships" validate constraint "partnerships_user2_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.delete_user_data()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  uid uuid := auth.uid();
BEGIN
  -- 1. Delete only THIS user's expenses (not partner's)
  DELETE FROM expenses WHERE paid_by = uid;

  -- 2. For partnerships where this user is user2: detach by clearing user2_id and archiving
  UPDATE partnerships
    SET user2_id = NULL, status = 'archived'
    WHERE user2_id = uid AND status = 'active';

  -- 3. For partnerships where this user is user1 AND still has a partner:
  --    archive and clear user2_id (protect partner)
  UPDATE partnerships
    SET user2_id = NULL, status = 'archived'
    WHERE user1_id = uid AND user2_id IS NOT NULL AND status = 'active';

  -- 4. Delete solo partnerships (pending, or archived with no partner) + their categories
  DELETE FROM categories
    WHERE partnership_id IN (
      SELECT id FROM partnerships
      WHERE user1_id = uid AND user2_id IS NULL
    );
  DELETE FROM partnerships
    WHERE user1_id = uid AND user2_id IS NULL;

  -- 5. Delete profile
  DELETE FROM profiles WHERE id = uid;

  -- 6. Sign out handled client-side
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_user_data(target_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- 1. このユーザーが支払った expenses のみ削除（パートナーの分は残す）
  DELETE FROM expenses WHERE paid_by = target_user_id;

  -- 2. user2 として参加しているパートナーシップ: 自分を外してアーカイブ
  UPDATE partnerships
    SET user2_id = NULL, status = 'archived'
    WHERE user2_id = target_user_id;

  -- 3. user1 かつパートナーがいる場合: パートナーにオーナーを移譲してアーカイブ
  UPDATE partnerships
    SET user1_id = user2_id, user2_id = NULL, status = 'archived'
    WHERE user1_id = target_user_id AND user2_id IS NOT NULL;

  -- 4. 残った solo パートナーシップ（パートナーなし）のカテゴリと本体を削除
  DELETE FROM categories
    WHERE partnership_id IN (
      SELECT id FROM partnerships WHERE user1_id = target_user_id
    );
  DELETE FROM partnerships WHERE user1_id = target_user_id;

  -- 5. プロフィール削除
  DELETE FROM profiles WHERE id = target_user_id;
END;
$function$
;

grant delete on table "public"."categories" to "anon";

grant insert on table "public"."categories" to "anon";

grant references on table "public"."categories" to "anon";

grant select on table "public"."categories" to "anon";

grant trigger on table "public"."categories" to "anon";

grant truncate on table "public"."categories" to "anon";

grant update on table "public"."categories" to "anon";

grant delete on table "public"."categories" to "authenticated";

grant insert on table "public"."categories" to "authenticated";

grant references on table "public"."categories" to "authenticated";

grant select on table "public"."categories" to "authenticated";

grant trigger on table "public"."categories" to "authenticated";

grant truncate on table "public"."categories" to "authenticated";

grant update on table "public"."categories" to "authenticated";

grant delete on table "public"."categories" to "service_role";

grant insert on table "public"."categories" to "service_role";

grant references on table "public"."categories" to "service_role";

grant select on table "public"."categories" to "service_role";

grant trigger on table "public"."categories" to "service_role";

grant truncate on table "public"."categories" to "service_role";

grant update on table "public"."categories" to "service_role";

grant delete on table "public"."encryption_keys" to "anon";

grant insert on table "public"."encryption_keys" to "anon";

grant references on table "public"."encryption_keys" to "anon";

grant select on table "public"."encryption_keys" to "anon";

grant trigger on table "public"."encryption_keys" to "anon";

grant truncate on table "public"."encryption_keys" to "anon";

grant update on table "public"."encryption_keys" to "anon";

grant delete on table "public"."encryption_keys" to "authenticated";

grant insert on table "public"."encryption_keys" to "authenticated";

grant references on table "public"."encryption_keys" to "authenticated";

grant select on table "public"."encryption_keys" to "authenticated";

grant trigger on table "public"."encryption_keys" to "authenticated";

grant truncate on table "public"."encryption_keys" to "authenticated";

grant update on table "public"."encryption_keys" to "authenticated";

grant delete on table "public"."encryption_keys" to "service_role";

grant insert on table "public"."encryption_keys" to "service_role";

grant references on table "public"."encryption_keys" to "service_role";

grant select on table "public"."encryption_keys" to "service_role";

grant trigger on table "public"."encryption_keys" to "service_role";

grant truncate on table "public"."encryption_keys" to "service_role";

grant update on table "public"."encryption_keys" to "service_role";

grant delete on table "public"."expenses" to "anon";

grant insert on table "public"."expenses" to "anon";

grant references on table "public"."expenses" to "anon";

grant select on table "public"."expenses" to "anon";

grant trigger on table "public"."expenses" to "anon";

grant truncate on table "public"."expenses" to "anon";

grant update on table "public"."expenses" to "anon";

grant delete on table "public"."expenses" to "authenticated";

grant insert on table "public"."expenses" to "authenticated";

grant references on table "public"."expenses" to "authenticated";

grant select on table "public"."expenses" to "authenticated";

grant trigger on table "public"."expenses" to "authenticated";

grant truncate on table "public"."expenses" to "authenticated";

grant update on table "public"."expenses" to "authenticated";

grant delete on table "public"."expenses" to "service_role";

grant insert on table "public"."expenses" to "service_role";

grant references on table "public"."expenses" to "service_role";

grant select on table "public"."expenses" to "service_role";

grant trigger on table "public"."expenses" to "service_role";

grant truncate on table "public"."expenses" to "service_role";

grant update on table "public"."expenses" to "service_role";

grant delete on table "public"."partnerships" to "anon";

grant insert on table "public"."partnerships" to "anon";

grant references on table "public"."partnerships" to "anon";

grant select on table "public"."partnerships" to "anon";

grant trigger on table "public"."partnerships" to "anon";

grant truncate on table "public"."partnerships" to "anon";

grant update on table "public"."partnerships" to "anon";

grant delete on table "public"."partnerships" to "authenticated";

grant insert on table "public"."partnerships" to "authenticated";

grant references on table "public"."partnerships" to "authenticated";

grant select on table "public"."partnerships" to "authenticated";

grant trigger on table "public"."partnerships" to "authenticated";

grant truncate on table "public"."partnerships" to "authenticated";

grant update on table "public"."partnerships" to "authenticated";

grant delete on table "public"."partnerships" to "service_role";

grant insert on table "public"."partnerships" to "service_role";

grant references on table "public"."partnerships" to "service_role";

grant select on table "public"."partnerships" to "service_role";

grant trigger on table "public"."partnerships" to "service_role";

grant truncate on table "public"."partnerships" to "service_role";

grant update on table "public"."partnerships" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";


  create policy "Partnership members can manage categories"
  on "public"."categories"
  as permissive
  for all
  to public
using ((partnership_id IN ( SELECT partnerships.id
   FROM public.partnerships
  WHERE ((auth.uid() = partnerships.user1_id) OR (auth.uid() = partnerships.user2_id)))));



  create policy "Users can manage their own keys"
  on "public"."encryption_keys"
  as permissive
  for all
  to public
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));



  create policy "Partnership members can manage expenses"
  on "public"."expenses"
  as permissive
  for all
  to public
using ((partnership_id IN ( SELECT partnerships.id
   FROM public.partnerships
  WHERE ((auth.uid() = partnerships.user1_id) OR (auth.uid() = partnerships.user2_id)))));



  create policy "Anyone can find pending partnership by invite code"
  on "public"."partnerships"
  as permissive
  for select
  to authenticated
using ((status = 'pending'::text));



  create policy "Anyone can join pending partnership"
  on "public"."partnerships"
  as permissive
  for update
  to authenticated
using ((status = 'pending'::text))
with check (((status = 'active'::text) AND (user2_id = auth.uid())));



  create policy "Users can create partnerships"
  on "public"."partnerships"
  as permissive
  for insert
  to public
with check ((auth.uid() = user1_id));



  create policy "Users can join pending partnerships"
  on "public"."partnerships"
  as permissive
  for update
  to public
using (((status = 'pending'::text) AND (user2_id IS NULL)))
with check ((auth.uid() = user2_id));



  create policy "Users can read own partnerships"
  on "public"."partnerships"
  as permissive
  for select
  to public
using (((auth.uid() = user1_id) OR (auth.uid() = user2_id)));



  create policy "Users can update own partnerships"
  on "public"."partnerships"
  as permissive
  for update
  to public
using (((auth.uid() = user1_id) OR (auth.uid() = user2_id)));



  create policy "Users can delete own profile"
  on "public"."profiles"
  as permissive
  for delete
  to public
using ((auth.uid() = id));



  create policy "Users can insert own profile"
  on "public"."profiles"
  as permissive
  for insert
  to public
with check ((auth.uid() = id));



  create policy "Users can read own profile"
  on "public"."profiles"
  as permissive
  for select
  to public
using ((auth.uid() = id));



  create policy "Users can read partner profile"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (((id = auth.uid()) OR (id IN ( SELECT partnerships.user1_id
   FROM public.partnerships
  WHERE ((partnerships.user2_id = auth.uid()) AND (partnerships.status = 'active'::text))
UNION
 SELECT partnerships.user2_id
   FROM public.partnerships
  WHERE ((partnerships.user1_id = auth.uid()) AND (partnerships.status = 'active'::text))))));



  create policy "Users can update own profile"
  on "public"."profiles"
  as permissive
  for update
  to public
using ((auth.uid() = id));



