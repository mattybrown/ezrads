require_relative 'test_helper'

class PublicationTest < MiniTest::Test
  def setup
    login_as User.new(username: 'test', role: 1, paper_id: 1, password: 'test')
  end

  def test_shows_ads_in_publication
    get '/'
    assert last_response.ok?
    assert_includes last_response.body, '/view/ad', 'Should show view/ad link if ads'
  end

  def test_shows_publication_rop
    get '/view/publication/1/rop'
    assert last_response.ok?
    assert_includes last_response.body, 'TestPublication', 'Should show publication name'
  end

  def test_shows_publication_classie
    get '/view/publication/1/classie'
    assert last_response.ok?
    assert_includes last_response.body, 'TestPublication', 'Should show publication name'
  end

  def test_shows_single_publication_feature
    get '/view/publication/1/feature/1'
    assert last_response.ok?
    assert_includes last_response.body, 'TestPublication', 'Should show publication name'
  end

  def test_shows_all_publications
    get '/view/publications'
    assert last_response.ok?
    assert_includes last_response.body, 'TestPublication', 'Should show publication name'
  end

  def test_shows_single_publication
    get '/view/publication/1'
    assert last_response.ok?
    assert_includes last_response.body, 'TestPaper', 'Should show paper name'
  end

  def test_shows_create_publication
    get '/create/publication'
    assert last_response.ok?
    assert_includes last_response.body, 'Create single publication', 'Should show create title'
  end

end
