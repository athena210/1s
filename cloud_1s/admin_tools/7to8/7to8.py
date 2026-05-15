#!/usr/bin/env python3

import sys
import os
import xml.etree.ElementTree as ET


def remove_elements(xml_file, parent_path, recursive, element_type, attribute_name, attribute_value, sub_element_type=None, sub_attribute_name=None, sub_attribute_value=None):
    """
    Удаляет элементы из XML-файла по заданным критериям и перезаписывает исходный файл.

    Параметры:
        xml_file (str): Путь к XML-файлу
        parent_path (str): Путь к родительскому элементу (XPath)
        recursive (bool): Искать элементы рекурсивно (True) или только прямые потомки (False)
        element_type (str): Тип удаляемого элемента (например, 'Объект')
        attribute_name (str): Название атрибута для фильтрации (например, 'Тип')
        attribute_value (str): Значение атрибута для фильтрации
        sub_element_type (str, optional): Тип дочернего элемента для дополнительной фильтрации (например, 'Свойство')
        sub_attribute_name (str, optional): Название атрибута дочернего элемента
        sub_attribute_value (str, optional): Значение атрибута дочернего элемента
    """
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()

        # Проверяем, что корневой элемент это <ФайлОбмена>
        parent = None
        if root.tag.endswith('ФайлОбмена') and (parent_path == 'ФайлОбмена' or not parent_path):
            parent = root
            # print("Родительский элемент <ФайлОбмена> является корневым")
        else:
            parent = root.find(parent_path)
            if parent is None:
                # print(f"Родительский элемент '{parent_path}' не найден. Корневой элемент: {root.tag}")
                # print("Дочерние элементы корневого элемента:")
                # for child in root:
                #     print(f"  {child.tag}, атрибуты: {child.attrib}")
                return

        namespace = ''
        if '}' in root.tag:
            namespace = root.tag.split('}')[0][1:]
            print(f"Обнаружено пространство имён: {namespace}")
            ET.register_namespace('', namespace)
            search_path = f"{{{namespace}}}{element_type}" if not recursive else f".//{{{namespace}}}{element_type}"
            sub_search_path = f"{{{namespace}}}{sub_element_type}" if sub_element_type and not recursive else f".//{{{namespace}}}{sub_element_type}" if sub_element_type else None
        else:
            search_path = element_type if not recursive else f".//{element_type}"
            sub_search_path = sub_element_type if sub_element_type and not recursive else f".//{sub_element_type}" if sub_element_type else None

        elements_to_remove = []
        for elem in parent.findall(search_path):
            if elem.get(attribute_name) == attribute_value:
                # print(f"Найден элемент {elem.tag} с {attribute_name}={attribute_value}, атрибуты: {elem.attrib}")
                # Если указаны sub_element_type и sub_attribute, ищем дочерние элементы
                if sub_element_type and sub_attribute_name and sub_attribute_value:
                    for sub_elem in elem.findall(sub_search_path):
                        if sub_elem.get(sub_attribute_name) == sub_attribute_value:
                            # print(f"  Найден дочерний элемент {sub_elem.tag} с {sub_attribute_name}={sub_attribute_value}, атрибуты: {sub_elem.attrib}")
                            elements_to_remove.append((elem, sub_elem))
                else:
                    elements_to_remove.append((parent, elem))

        # Удаляем найденные элементы
        for parent_elem, elem_to_remove in elements_to_remove:
            parent_elem.remove(elem_to_remove)

        # Перезаписываем исходный файл
        tree.write(xml_file, encoding='unicode', xml_declaration=False)
        print(f"Файл успешно обработан и перезаписан: {xml_file}")
        print(f"Удалено элементов: {len(elements_to_remove)}")

    except ET.ParseError as e:
        print(f"Error parsing XML: {e}")
    except Exception as e:
        print(f"Error: {e}")


def main():

    input_file = 'db.xml'
    if len(sys.argv) > 1:
        input_file = sys.argv[1]


    dir_user = os.getenv('DIR_USER')
    dir_group = os.getenv('DIR_GROUP')
    if \
      not dir_user or \
      not dir_group or \
      dir_user != str(os.geteuid()) or \
      dir_group != str(os.getegid()):
        print("Must be started from container as non-root.")
        return 1

    if not os.path.isfile(input_file):
        print(f"Can not open the file {input_file}")
        return 1


    print(f"Using {input_file}")
    os.popen(f'cp -a {input_file} {input_file}__bak')

    remove_elements(
        xml_file = input_file,
        parent_path = 'ФайлОбмена',
        recursive = False,
        element_type = 'Объект',
        attribute_name = 'Тип',
        attribute_value='РегистрСведенийЗапись.УчетнаяПолитикаОрганизаций'
    )

    remove_elements(
        xml_file = input_file,
        parent_path = 'ФайлОбмена',
        recursive = False,
        element_type = 'Объект',
        attribute_name = 'Тип',
        attribute_value='РегистрСведенийЗапись.МетодыРаспределенияКосвенныхРасходовОрганизаций'
    )

    remove_elements(
        xml_file = input_file,
        parent_path = 'ФайлОбмена',
        recursive = False,
        element_type = 'Объект',
        attribute_name = 'Тип',
        attribute_value='РегистрСведенийЗапись.СтавкиНалогаНаПрибыльДляВсехОрганизаций'
    )

    remove_elements(
        xml_file = input_file,
        parent_path = 'ФайлОбмена',
        recursive = False,
        element_type = 'Объект',
        attribute_name = 'Тип',
        attribute_value='СправочникСсылка.Контрагенты',
        sub_element_type='Свойство',
        sub_attribute_name='Имя',
        sub_attribute_value='ОсновнойДоговорКонтрагента'
    )

    remove_elements(
        xml_file = input_file,
        parent_path = 'ФайлОбмена',
        recursive = False,
        element_type = 'Объект',
        attribute_name = 'Тип',
        attribute_value='СправочникСсылка.Номенклатура',
        sub_element_type='Свойство',
        sub_attribute_name='Имя',
        sub_attribute_value='СтавкаНДС'
    )


if __name__ == "__main__":
    raise SystemExit(main())
