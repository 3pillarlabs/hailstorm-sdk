# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
Product.find_or_create_by!(sku: '49831', title: 'Iphone 4', price: 8.99)
Product.find_or_create_by!(sku: '49832', title: 'Iphone 4s', price: 18.99)
Product.find_or_create_by!(sku: '49833', title: 'Iphone 5', price: 28.99)
Product.find_or_create_by!(sku: '49834', title: 'Iphone 5S', price: 38.99)
Product.find_or_create_by!(sku: '49835', title: 'Iphone SE', price: 48.99)
Product.find_or_create_by!(sku: '49836', title: 'Iphone 6', price: 58.99)
Product.find_or_create_by!(sku: '49837', title: 'Iphone 6S', price: 68.99)
Product.find_or_create_by!(sku: '49838', title: 'Iphone 6S Plus', price: 78.99)
Product.find_or_create_by!(sku: '49839', title: 'Iphone 7', price: 98.99)
Product.find_or_create_by!(sku: '49840', title: 'Iphone 7 Plus', price: 108.99)
