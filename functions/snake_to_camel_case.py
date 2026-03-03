def snake_to_camel_case(input_string):
    """Convert snake_case string to camelCase"""
    if not input_string:
        return None

    parts = input_string.lower().split('_')
    result = parts[0]

    for i in range(1, len(parts)):
        if len(parts[i]) > 0:
            result += parts[i][0].upper() + parts[i][1:]

    return result
