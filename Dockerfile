# syntax = docker/dockerfile:1 

# กำหนดค่า default version ของ Ruby ที่จะใช้ในการ build image
ARG RUBY_VERSION=3.3.1 

# ใช้ image ของ Ruby ที่เป็น slim version ในการ build image นี้ และตั้งชื่อ image ว่า "base"
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

# กำหนด working directory ใน container ให้เป็น /rails ซึ่งจะเป็นที่เก็บโค้ดของแอป
WORKDIR /rails

# ตั้งค่า environment variables เพื่อกำหนดการทำงานของ Rails ในโหมด production 
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# สร้าง image ใหม่จาก base image ที่ตั้งไว้ และตั้งชื่อเฟสนี้ว่า "build"
FROM base as build

# ติดตั้งแพ็กเกจที่จำเป็นสำหรับการสร้าง gems (library ของ Ruby)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libvips pkg-config libpq-dev

# คัดลอกไฟล์ Gemfile และ Gemfile.lock จากเครื่องของเราไปยัง container
COPY Gemfile Gemfile.lock ./

# ติดตั้ง gems ทั้งหมดตามที่ระบุใน Gemfile และลบ cache ต่างๆ เพื่อลดขนาดของ image จากนั้นทำการ precompile ด้วย bootsnap เพื่อเร่งความเร็วในการรันแอป
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# คัดลอกโค้ดแอปทั้งหมดจากเครื่องเราไปยัง container
COPY . .

# ทำการ precompile โค้ดในโฟลเดอร์ app/ และ lib/ เพื่อเพิ่มความเร็วในการเริ่มต้นแอป
RUN bundle exec bootsnap precompile app/ lib/

# ทำการ precompile assets โดยไม่ต้องการ RAILS_MASTER_KEY เพื่อเตรียมพร้อมสำหรับการใช้งานใน production
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# เริ่ม image ใหม่จาก base อีกครั้งเพื่อสร้าง image สุดท้ายสำหรับ deployment
FROM base

# ติดตั้งแพ็กเกจที่จำเป็นสำหรับการรันแอป รวมถึงไลบรารี runtime ของ PostgreSQL (libpq5)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libsqlite3-0 libvips libpq5 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# คัดลอก gems ที่สร้างไว้ในเฟส build มาไว้ใน image สุดท้าย
COPY --from=build /usr/local/bundle /usr/local/bundle

# คัดลอกโค้ดแอปที่สร้างไว้ในเฟส build มาไว้ใน image สุดท้าย
COPY --from=build /rails /rails

# สร้าง user rails เพื่อใช้งานใน container และกำหนดสิทธิ์ให้ user นี้เป็นเจ้าของโฟลเดอร์ที่สำคัญต่างๆ เพื่อเพิ่มความปลอดภัย
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp

# เปลี่ยน user ที่จะใช้รัน container ให้เป็น rails
USER rails:rails

# กำหนดคำสั่งเริ่มต้นเมื่อ container รัน โดยจะเรียกใช้งาน docker-entrypoint ซึ่งเป็นสคริปต์เตรียมฐานข้อมูล
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# เปิดพอร์ต 3000 เพื่อให้ภายนอกสามารถเข้าถึงเว็บเซิร์ฟเวอร์ใน container ได้
EXPOSE 3000

# กำหนดคำสั่งเริ่มต้นเมื่อ container รันให้เป็นการเริ่มต้นเซิร์ฟเวอร์ Rails
CMD ["./bin/rails", "server"]
