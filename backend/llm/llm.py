llm_type = 1


def llm(query):
    def gpt_4o(query):
        return f"Response from gpt_4o for query: {query}"

    def llm_type_2(query):
        return f"Response from LLM type 2 for query: {query}"

    def llm_type_3(query):
        return f"Response from LLM type 3 for query: {query}"

    # Dictionary to map llm_type to the corresponding function
    switch = {
        1: gpt_4o,
        2: llm_type_2,
        3: llm_type_3,
    }

    # Get the function based on llm_type and call it
    selected_llm = switch.get(llm_type, 1)
    response = selected_llm(query)

    return response
