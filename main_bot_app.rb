require 'telegram/bot'
require 'sqlite3'
require 'active_record'
token = '782039073:AAGQ4Bo_REKZCmHcLLdpRdU8goP3INBYnpA'
# https://www.techcareerbooster.com/blog/use-activerecord-in-your-ruby-project
# https://blog.teamtreehouse.com/active-record-without-rails-app

class Category < ActiveRecord::Base
    has_many :products
end

class Product < ActiveRecord::Base
    belongs_to :category
end

class User < ActiveRecord::Base
    has_many :orders
    serialize :used_keyboards_array, Array
    serialize :user_basket_array, Array
    serialize :user_final_basket, Array
end

class Order < ActiveRecord::Base
    belongs_to :user
    serialize :user_complete_order, Array
end

def db_configuration
    db_configuration_file = File.join(File.expand_path('..', __FILE__), 'db', 'config.yml')
    YAML.load(File.read(db_configuration_file))
end
ActiveRecord::Base.establish_connection(db_configuration["development"])

keyboards = {
    :start_keyboard => Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: ['📖 Меню 📖',%w(💰\ Корзина\ 💰 🎨\ Галерея\ 🎨),%w(🎉\ Мероприятия\ 🎉 🌍\ Геолокация\ 🌍)]),
    :basket_keyboard => Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: ['🚀 Заказать доставку 🚀','🏃 Забрать в ресторане 🏃','❎ Удалить позицию ❎','⏪ Назад ⏪']),
    :menu_keyboard => Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(🍴Кухня🍴 🍷Бар🍷),'👌Новинки👌',%w(⏪\ Назад\ ⏪ 🚩\ Главн.\ меню\ 🚩)]),
    :kitchen_menu=>Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(Основное Супы),%w(Закуски Сладкое),%w(⏪\ Назад\ ⏪ 🚩\ Главн.\ меню\ 🚩)]),
    :zakuski=>Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(Салаты Специальное),%w(Снеки),%w(⏪\ Назад\ ⏪ 🚩\ Главн.\ меню\ 🚩)]),
    :bar_keyboard=>Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(Вино Крепкое Пиво),%w(Коктейли Ликеры Настойки),%w(⏪\ Назад\ ⏪ 🚩\ Главн.\ меню\ 🚩)]),
    :beer=>Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(На\ разлив),%w(Бутылочное),%w(⏪\ Назад\ ⏪ 🚩\ Главн.\ меню\ 🚩)]),
    :back_keyboard=>Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(⏪\ Назад\ ⏪ 🚩\ Главн.\ меню\ 🚩)]),
    :admin_keyboard => Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(💡\ Добавить\ 💡 📝\ Изменить\ 📝 ❎\ Удалить\ ❎),%w(📣\ Рассылка\ 📣 🚩\ Главн.\ меню\ 🚩)]),
}
basket = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [Telegram::Bot::Types::InlineKeyboardButton.new(text: "Добавить в корзину", callback_data: "Добавить в корзину")])
user_photo_msg = []
message_data_array =[]
user_msg_by_usid = {} 

Telegram::Bot::Client.run(token) do |bot|
bot.listen do |message| 
Thread.start do 
    all_categories = Category.all
    keyboards_hash_by_category = Hash.new{|hsh,key| hsh[key] = [] }
    all_categories.each do |category|
        category.products.each do |product|
            keyboards_hash_by_category[category.category_name].push [Telegram::Bot::Types::InlineKeyboardButton.new(text: product.name, callback_data: product.name)]
        end
    end

    categories_for_inline_call = []
    all_categories.each do |category|
        categories_for_inline_call << category.category_name
    end

case message
    when Telegram::Bot::Types::CallbackQuery
        if message.data != 'Добавить в корзину' 
            product = Product.find_by(name: message.data)
            product_category = Category.find(product.category_id)
            user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id)
            user.user_basket_array << product.name
            user.save
            if product_category.category_name == '🎉 Мероприятия 🎉'
                bot.api.send_photo(chat_id: message.from.id,  photo: product.image_id, caption: product.description) 
            else
                bot.api.send_photo(chat_id: message.from.id,  photo: product.image_id, caption: product.description, reply_markup: basket) 
            end
        else 
            user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id)
            bot.api.send_message(chat_id: message.from.id, text: "Продукт добавлен в корзину")
            user.user_final_basket << user.user_basket_array.last
            user.save
        end

    when Telegram::Bot::Types::Message  
        if categories_for_inline_call.include?(message.text) 
            keyboards_array = []
            keyboards_array = keyboards_hash_by_category[message.text]
            inline_kb = []
            keyboards_array.each do |keyboard|
                inline_kb << keyboard
            end
            markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: inline_kb)
            bot.api.send_message(chat_id: message.chat.id, text: '🙌', reply_markup: markup)
        end
        user_photo_msg << message.photo 

    case message.text
    when '/start','/menu'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        bot.api.send_message( chat_id: message.chat.id, text: "Привет, #{message.from.first_name}")
        use_keyboard = keyboards[:start_keyboard]
        bot.api.send_sticker( chat_id: message.chat.id, sticker: 'CAADAgADJAIAAs9fiweA2Bg61RIH0wI', reply_markup: use_keyboard)
        user.used_keyboards_array << use_keyboard
        user.save
       
    when '📖 Меню 📖'    
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        use_keyboard = keyboards[:menu_keyboard]
        bot.api.send_sticker( chat_id: message.chat.id, sticker: 'CAADAgAEAgACz1-LByOhKKaJLk1kAg', reply_markup: use_keyboard)
        user.used_keyboards_array << use_keyboard
        user.save

    when '🎨 Галерея 🎨'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id)
        bot.api.send_photo(chat_id: message.from.id, photo: 'AgADAgADNKoxG232KEm8LjQqx20F83R2Xw8ABBhFCjdF9i2AQFgDAAEC')
        bot.api.send_photo(chat_id: message.from.id, photo: 'AgADAgADNaoxG232KEnNnEaaIbK_RUFBOQ8ABA7eaHvkM_OJUBsEAAEC')
        bot.api.send_photo(chat_id: message.from.id, photo: 'AgADAgADOaoxG232KEklhh0VYOYgfVlKOQ8ABFiFd7CJ1-WwyxcEAAEC')
        bot.api.send_photo(chat_id: message.from.id, photo: 'AgADAgADOqoxG232KEkf5AVbt0odQFJFOQ8ABBKuq4BsGaSSth8EAAEC')
        bot.api.send_video(chat_id: message.from.id, video: 'BAADAgAD5wIAAm32KEkQqYcleusZQwI')
    when '🍴Кухня🍴'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        use_keyboard = keyboards[:kitchen_menu]
        bot.api.send_sticker( chat_id: message.chat.id, sticker: 'CAADAgADBQIAAs9fiwd4nUTXRdM4EwI', reply_markup: use_keyboard)
        user.used_keyboards_array << use_keyboard
        user.save

    when 'Закуски'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        use_keyboard = keyboards[ :zakuski]
        bot.api.send_message( chat_id: message.chat.id, text: '💬', reply_markup: use_keyboard)
        user.used_keyboards_array << use_keyboard
        user.save

    when '🍷Бар🍷'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        use_keyboard = keyboards[:bar_keyboard]
        bot.api.send_sticker( chat_id: message.chat.id, sticker: 'CAADAgADDgIAAs9fiwcjQhS7p5pQNwI', reply_markup: use_keyboard)
        user.used_keyboards_array << use_keyboard
        user.save

    when 'Пиво'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        use_keyboard = keyboards[:beer]
        bot.api.send_message(chat_id: message.chat.id, text: '💬', reply_markup: use_keyboard)
        user.used_keyboards_array << use_keyboard
        user.save
    when '💰 Корзина 💰'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        if user.user_final_basket.empty?
            bot.api.send_message(chat_id: message.chat.id, text: "🙊Пока в вашей корзине пусто🙊\nПолистайте меню и решите что бы Вы хотели заказать\nКак решите - нажмите кнопку (Добавить в корзину)", reply_markup: use_keyboard)
        else
            use_keyboard = keyboards[:basket_keyboard]
            x=''   
            user.user_final_basket.each_with_index do |value, index| 
                x+="#{index+1}) #{value}\n"
            end
            use_keyboard = keyboards[:basket_keyboard]
            bot.api.send_message(chat_id: message.chat.id, text: "🍕 Ваш заказ 🍕\n#{x}", reply_markup: use_keyboard)
            user.used_keyboards_array << use_keyboard
            user.save
        end
    
    when '🚀 Заказать доставку 🚀'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        bot.api.send_message(chat_id: message.chat.id, text: "Как к Вам обращаться?")
        user_msg_by_usid[user.usid] = nil 
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        if user_msg_by_usid[user.usid]=='⏪ Назад ⏪'
            bot.api.send_message(chat_id: message.chat.id, text: "Отмена заказа доставки")
        else
        final_order = Order.create(attributes = nil)
        final_order.entered_name = user_msg_by_usid[user.usid] 
        bot.api.send_message(chat_id: message.chat.id, text: "Ваш номер телефона")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        final_order.entered_phone = user_msg_by_usid[user.usid]
        bot.api.send_message(chat_id: message.chat.id, text: "Адрес для доставки")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        final_order.entered_adress = user_msg_by_usid[user.usid]
        final_order.user_complete_order << user.user_final_basket
        final_order.save
        final_order_details = [final_order.entered_name, final_order.entered_phone, final_order.entered_adress]
        user.orders << final_order
        user.user_final_basket.clear
        user.save
        x=''                                                                                                
        final_order.user_complete_order.flatten.each_with_index do |value,index|
            x+="#{index+1}) #{value}\n"
        end
        use_keyboard = keyboards[:start_keyboard]
        bot.api.send_message(chat_id: message.chat.id, text: "📋Данные заказа📋\nИмя - #{final_order_details[0]}\nТелефон - #{final_order_details[1]}\nАдрес - #{final_order_details[2]}\n\n👇Позиции заказа👇\n#{x}") 
        bot.api.send_message(chat_id: message.chat.id, text: "✅Ваш заказ принят✅\nМенеджер свяжется с Вами в кратчайшие сроки.\nЕсли возникли вопросы звоните по номеру: (073)-13-70-320",reply_markup:use_keyboard) 
        oleg_admin_id = 198875715 
        danil_admin_id = 255989309
        nastya_admin_id = 176895979
        bot.api.send_message(chat_id: danil_admin_id, text: "Заказ ##{final_order.id}# - ДОСТАВКА\n\n📋Данные заказа📋\nИмя - #{final_order_details[0]}\nТелефон - #{final_order_details[1]}\nАдрес - #{final_order_details[2]}\n\n👇Позиции заказа👇\n#{x}") 
        end
    when '🏃 Забрать в ресторане 🏃'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        bot.api.send_message(chat_id: message.chat.id, text: "Как к Вам обращаться?")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        
        if user_msg_by_usid[user.usid]=='⏪ Назад ⏪'
            bot.api.send_message(chat_id: message.chat.id, text: "Отмена заказа доставки")
        else
        final_order = Order.create(attributes = nil)
        final_order.entered_name = user_msg_by_usid[user.usid]
        bot.api.send_message(chat_id: message.chat.id, text: "Ваш номер телефона") 
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end 
        final_order.entered_phone = user_msg_by_usid[user.usid]
        final_order.user_complete_order << user.user_final_basket
        final_order.save
        final_order_details = [final_order.entered_name, final_order.entered_phone]
        user.orders << final_order
        user.user_final_basket.clear
        user.save
        x=''                                                                                                
        final_order.user_complete_order.flatten.each_with_index do |value,index|
            x+="#{index+1}) #{value}\n"
        end
        use_keyboard = keyboards[:start_keyboard]
        bot.api.send_message(chat_id: message.chat.id, text: "📋Данные заказа📋\nИмя - #{final_order_details[0]}\nТелефон - #{final_order_details[1]}\n\n👇Позиции заказа👇\n#{x}") 
        bot.api.send_message(chat_id: message.chat.id, text: "✅Ваш заказ принят✅\nМенеджер свяжется с Вами в кратчайшие сроки.\nЕсли возникли вопросы звоните по номеру: (073)-13-70-320",reply_markup:use_keyboard) 
        oleg_admin_id = 198875715 
        danil_admin_id = 255989309
        nastya_admin_id = 176895979
        bot.api.send_message(chat_id: danil_admin_id, text: "Заказ ##{final_order.id}# - САМОВЫВОЗ\n\n📋Данные заказа📋\nИмя - #{final_order_details[0]}\nТелефон - #{final_order_details[1]}\n\n👇Позиции заказа👇\n#{x}") 
        bot.api.send_message(chat_id: oleg_admin_id, text: "Заказ ##{final_order.id}# - САМОВЫВОЗ\n\n📋Данные заказа📋\nИмя - #{final_order_details[0]}\nТелефон - #{final_order_details[1]}\n\n👇Позиции заказа👇\n#{x}")    
        end

    when '❎ Удалить позицию ❎'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        if user.user_final_basket.empty?
            bot.api.send_message(chat_id: message.chat.id, text: "🙊Пока в вашей корзине пусто🙊\nПолистайте меню и решите что бы Вы хотели заказать\nКак решите - нажмите кнопку (Добавить в корзину)", reply_markup: use_keyboard)
        else
        bot.api.send_message(chat_id: message.chat.id, text: "Введите номер блюда, которое хотите удалить из заказа")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        delete_product_number = user_msg_by_usid[user.usid]
        user.user_final_basket.delete_at(delete_product_number.to_i-1)
        user.save
        bot.api.send_message(chat_id: message.chat.id, text: "Блюдо удалено из заказа")
        x=''                                                                                                
        user.user_final_basket.flatten.each_with_index do |value,index|
            x+="#{index+1}) #{value}\n"
        end
        bot.api.send_message(chat_id: message.chat.id, text: "🌝 Теперь ваш заказ такой 🌝\n#{x}")
        bot.api.send_message(chat_id: message.chat.id, text: "Теперь в вашей корзине пусто!\nПолистайте меню и решите что бы Вы хотели заказать\nКак решите - нажмите кнопку (Добавить в корзину)") if user.user_final_basket.empty? == true
        end
    when '👌Новинки👌'
        novelty=Product.find_by(name:'👌Новинки👌')

    when '🎉 Мероприятия 🎉'
        event=Product.find_by(name:'🎉 Мероприятия 🎉')
    
    when '🌍 Геолокация 🌍'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        bot.api.send_location(chat_id: message.chat.id, latitude: 50.5216073, longitude: 30.2385393)
        bot.api.send_message(chat_id: message.chat.id, text: "Київська обл., м.Ірпінь, вул. Грибоєдова 15")

    when '🚩 Главн. меню 🚩'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        use_keyboard = keyboards[:start_keyboard]
        bot.api.send_message(chat_id: message.chat.id, text: 'Возвращаемся в главное меню', reply_markup: use_keyboard)
        user.used_keyboards_array << use_keyboard
        user.used_keyboards_array.clear
        user.save

    when '⏪ Назад ⏪'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id) 
        user.used_keyboards_array.pop
        user.save
        if user.used_keyboards_array.size == 0
            use_keyboard = keyboards[:start_keyboard]
            user.save
        else
            use_keyboard = user.used_keyboards_array.last
            user.save
        end
        bot.api.send_message(chat_id: message.chat.id, text: "Назад",reply_markup: use_keyboard) 

    when '/stop'
        bot.api.send_message(chat_id: message.chat.id, text: "Пока, #{message.from.first_name}")

    when '/secret_password'
        use_keyboard = keyboards[:admin_keyboard]
        bot.api.send_message(chat_id: message.chat.id, text: "Вы вошли в панель администратора🔐\nТут вы можете управлять вашим меню в боте!", reply_markup: use_keyboard)
    
    when '📣 Рассылка 📣'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id)  
        users_all = User.all
        product1 = Product.find_by(category_id: 1) 
        product2 = Product.find_by(category_id: 2)
        bot.api.send_message(chat_id: message.chat.id, text: "Вы хотите разослать рекламу о каком то собитии, укажите пожалуйста из списка доступных или напишите свою рассылку")  
        bot.api.send_message(chat_id: message.chat.id, text: "Пропустите этот шаг если хотите прорекламировать что-то новое.\nДоступные рассылки:\n#{product1.name}, #{product2.name}")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        
        product = Product.find_by(name: user_msg_by_usid[user.usid]) || Product.create(name: 'One_time_adv')
        if user_msg_by_usid[user.usid] == product.name 
            users_all.each do |us|
            bot.api.send_photo(chat_id: us.usid,  photo: product.image_id, caption: product.description )
            bot.api.send_message(chat_id: message.chat.id, text: "Я разослал рекламу всем пользователям бота!") 
            end
        elsif product.name == 'One_time_adv'
            adv_product=Product.find_by(name: 'One_time_adv')
            bot.api.send_message(chat_id: message.chat.id, text: "Введите описание")  
            user_msg_by_usid[user.usid] = nil
            while user_msg_by_usid[user.usid] == nil 
                break if user_msg_by_usid[user.usid] != nil 
            end
            adv_product.description=user_msg_by_usid[user.usid]
            adv_product.save
            bot.api.send_message(chat_id: message.chat.id, text: "Скиньте фотографию") 
            user_photo_msg.clear 
            while user_photo_msg.empty? == true 
                break if user_photo_msg.empty? == false 
            end

            adv_image_file_id = user_photo_msg[0][1].file_id
            adv_product.image_id = adv_image_file_id
            adv_product.save
            user_photo_msg.clear
            users_all.each do |us|
            bot.api.send_photo(chat_id: us.usid, photo:  adv_product.image_id, caption: adv_product.description )
            end
            bot.api.send_message(chat_id: message.chat.id, text: "Я разослал рекламу всем пользователям бота!") 
            Product.where(name: 'One_time_adv').destroy_all
        end
   
    when '❎ Удалить ❎'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id)    
        bot.api.send_message(chat_id: message.chat.id, text: "Введите имя продукта который хотите удалить")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        Product.where(name: user_msg_by_usid[user.usid]).destroy_all
        bot.api.send_message(chat_id: message.chat.id, text: "Вы больше его не увидите, продукт удалён!")
    
    when '📝 Изменить 📝'
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id)    
        bot.api.send_message(chat_id: message.chat.id, text: "Введите имя продукта, который хотите изменить")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        edit_product = Product.find_by(name: user_msg_by_usid[user.usid])
        bot.api.send_message(chat_id: message.chat.id, text: "Введите новое имя продукта")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        edit_product.name = user_msg_by_usid[user.usid]
        edit_product.save
        bot.api.send_message(chat_id: message.chat.id, text: "Введите новое описание")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        edit_product.description = user_msg_by_usid[user.usid]
        edit_product.save
        bot.api.send_message(chat_id: message.chat.id, text: "Скиньте новую фотографию")
        user_photo_msg.clear 
            while user_photo_msg.empty? == true 
                break if user_photo_msg.empty? == false 
            end
        edit_product.image_id = user_photo_msg[0][1].file_id
        edit_product.save
        bot.api.send_message(chat_id: message.chat.id, text: "Продукт обновлен!")

    when '💡 Добавить 💡' 
        user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id)     
        bot.api.send_message(chat_id: message.chat.id, text: 'Введите имя блюда')      
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        new_procuct_name = user_msg_by_usid[user.usid]
        err=[1]
        new_product = Product.find_by(name: new_procuct_name) || err.clear
    if  err.empty? == true    
        new_product = Product.create(name: new_procuct_name)        
        new_product.save
        display_categories=Category.all
        category_names = []
        display_categories.each do |category|
            category_names << category.category_name
        end
        x=""
        category_names.each do |a|
            x+="-#{a}\n"     
        end
        bot.api.send_message(chat_id: message.chat.id, text: "Введите категорию блюда.\nСуществующие категории:\n#{x}")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        new_procuct_category = Category.find_by(category_name: user_msg_by_usid[user.usid]) || bot.api.send_message(chat_id: message.chat.id, text: "Такой категории не существует, попробуйте заново") && new_product.destroy && break
        new_procuct_category.products << new_product
        new_product.save  
        bot.api.send_message(chat_id: message.chat.id, text: "Введите описание блюда ")
        user_msg_by_usid[user.usid] = nil
        while user_msg_by_usid[user.usid] == nil 
            break if user_msg_by_usid[user.usid] != nil 
        end
        new_product.description = user_msg_by_usid[user.usid]
        new_product.save
        bot.api.send_message(chat_id: message.chat.id, text: "Скиньте фотографию блюда")
        user_photo_msg.clear 
            while user_photo_msg.empty? == true 
                break if user_photo_msg.empty? == false 
            end
        image_file_id = user_photo_msg[0][1].file_id
        new_product.image_id = image_file_id
        new_product.save
        user_photo_msg.clear
        bot.api.send_message(chat_id: message.chat.id, text: "Ваше блюдо добавлено!")
    else
        bot.api.send_message(chat_id: message.chat.id, text: "Такое имя уже есть, попробуйте заново")
    end    
end
user = User.find_by(usid: message.from.id) || User.create(usid: message.from.id)
user_msg_by_usid[user.usid] = message.text 
end 
end 
end
end

