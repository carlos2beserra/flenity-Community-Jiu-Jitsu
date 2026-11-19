import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { CommunityMediaService } from './community-media.service';
import { CommunityNotificationsService } from './community-notifications.service';
import { CommunityPostsService } from './community-posts.service';
import {
  asPrisma,
  author,
  createPrismaMock,
  PrismaMock,
  postRow,
  staffAuthor,
  testViews,
  viewer,
} from './community.test-helpers';

describe('CommunityPostsService', () => {
  let prisma: PrismaMock;
  let media: { claimable: jest.Mock; discard: jest.Mock };
  let notifications: { notify: jest.Mock; retract: jest.Mock };
  let service: CommunityPostsService;
  const me = viewer();

  beforeEach(() => {
    prisma = createPrismaMock();
    media = { claimable: jest.fn().mockResolvedValue([]), discard: jest.fn() };
    notifications = { notify: jest.fn(), retract: jest.fn() };
    service = new CommunityPostsService(
      asPrisma(prisma),
      testViews(),
      media as unknown as CommunityMediaService,
      notifications as unknown as CommunityNotificationsService,
    );
  });

  it('does not expose posts from another academy', async () => {
    prisma.communityPost.findFirst.mockResolvedValue(null);

    await expect(service.toggleLike(me, 'post-other-academy')).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.communityPost.findFirst).toHaveBeenCalledWith({
      where: { id: 'post-other-academy', academyId: 'academy-1' },
      select: { id: true, memberId: true },
    });
  });

  it('creates a post for the viewer profile with trimmed content', async () => {
    prisma.communityPost.create.mockResolvedValue(postRow({ content: 'Meu primeiro treino!' }));

    const post = await service.createPost(me, { content: '  Meu primeiro treino!  ' });

    expect(post).toMatchObject({ id: 'post-1', content: 'Meu primeiro treino!', likedByMe: false, media: [] });
    expect(prisma.communityPost.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: {
          academyId: 'academy-1',
          memberId: 'me',
          content: 'Meu primeiro treino!',
          kind: 'POST',
          media: { create: [] },
        },
      }),
    );
  });

  it('marks staff authors with their role label', async () => {
    prisma.communityPost.create.mockResolvedValue(postRow({ author: staffAuthor('prof-1') }));

    const post = await service.createPost(viewer('prof-1'), { content: 'Aula de hoje: passagem de guarda' });

    expect(post.author).toMatchObject({ name: 'Mestre Carlos', handle: 'mestre.carlos', isStaff: true, roleLabel: 'Professor' });
  });

  it('attaches claimed media in order and returns signed URLs', async () => {
    media.claimable.mockResolvedValue([
      { id: 'm2', kind: 'IMAGE' },
      { id: 'm1', kind: 'VIDEO' },
    ]);
    prisma.communityPost.create.mockResolvedValue(
      postRow({
        content: '',
        media: [{ media: { id: 'm2', kind: 'IMAGE' } }, { media: { id: 'm1', kind: 'VIDEO' } }],
      }),
    );

    const post = await service.createPost(me, { mediaIds: ['m2', 'm1'] });

    expect(media.claimable).toHaveBeenCalledWith(me, ['m2', 'm1']);
    expect(prisma.communityPost.create.mock.calls[0][0].data.media).toEqual({
      create: [
        { mediaId: 'm2', position: 0 },
        { mediaId: 'm1', position: 1 },
      ],
    });
    expect(post.media[0].url).toMatch(/^\/media\/m2\?exp=\d+&sig=[a-f0-9]{64}$/);
  });

  it('rejects a rola without exactly one video', async () => {
    media.claimable.mockResolvedValue([{ id: 'm1', kind: 'IMAGE' }]);

    await expect(service.createPost(me, { kind: 'REEL', mediaIds: ['m1'] })).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.communityPost.create).not.toHaveBeenCalled();
  });

  it('persists, removes likes and notifies the post author', async () => {
    prisma.communityPost.findFirst.mockResolvedValue({ id: 'post-1', memberId: 'author-1' });
    prisma.communityPostLike.findUnique.mockResolvedValue(null);

    await expect(service.toggleLike(me, 'post-1')).resolves.toEqual({ liked: true });
    expect(prisma.communityPostLike.create).toHaveBeenCalledWith({ data: { postId: 'post-1', memberId: 'me' } });
    expect(notifications.notify).toHaveBeenCalledWith({
      academyId: 'academy-1',
      actorId: 'me',
      recipientId: 'author-1',
      type: 'LIKE',
      postId: 'post-1',
    });

    prisma.communityPostLike.findUnique.mockResolvedValue({ id: 'like-1' });
    await expect(service.toggleLike(me, 'post-1')).resolves.toEqual({ liked: false });
    expect(prisma.communityPostLike.delete).toHaveBeenCalledWith({ where: { id: 'like-1' } });
    expect(notifications.retract).toHaveBeenCalledWith(
      expect.objectContaining({ actorId: 'me', recipientId: 'author-1', type: 'LIKE' }),
    );
  });

  it('persists a comment only after checking the post belongs to the academy', async () => {
    prisma.communityPost.findFirst.mockResolvedValue({ id: 'post-1', memberId: 'author-1' });
    prisma.communityPostComment.create.mockResolvedValue({
      id: 'comment-1',
      postId: 'post-1',
      content: 'Oss!',
      createdAt: new Date(),
      member: author('me'),
    });

    const comment = await service.addComment(me, 'post-1', { content: '  Oss!  ' });

    expect(comment).toMatchObject({ id: 'comment-1', author: { handle: 'ana.silva', isStaff: false } });
    expect(prisma.communityPostComment.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: { postId: 'post-1', memberId: 'me', content: 'Oss!' } }),
    );
    expect(notifications.notify).toHaveBeenCalledWith(expect.objectContaining({ type: 'COMMENT' }));
  });

  it('only lets the author delete a post and cleans up its media files', async () => {
    prisma.communityPost.findFirst.mockResolvedValue({ id: 'post-1', memberId: 'someone-else' });
    await expect(service.deletePost(me, 'post-1')).rejects.toBeInstanceOf(ForbiddenException);

    prisma.communityPost.findFirst.mockResolvedValue({ id: 'post-1', memberId: 'me' });
    prisma.communityPostMedia.findMany.mockResolvedValue([{ mediaId: 'm1' }]);
    await expect(service.deletePost(me, 'post-1')).resolves.toEqual({ deleted: true });
    expect(prisma.communityPost.delete).toHaveBeenCalledWith({ where: { id: 'post-1' } });
    expect(media.discard).toHaveBeenCalledWith(['m1']);
  });

  it('lets the post owner remove comments from others but not strangers', async () => {
    prisma.communityPost.findFirst.mockResolvedValue({ id: 'post-1', memberId: 'owner' });
    prisma.communityPostComment.findFirst.mockResolvedValue({ id: 'c1', memberId: 'commenter' });

    await expect(service.deleteComment(viewer('stranger'), 'post-1', 'c1')).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.deleteComment(viewer('owner'), 'post-1', 'c1')).resolves.toEqual({ deleted: true });
  });

  it('toggles a saved post', async () => {
    prisma.communityPost.findFirst.mockResolvedValue({ id: 'post-1', memberId: 'owner' });
    prisma.communityPostSave.findUnique.mockResolvedValueOnce(null).mockResolvedValueOnce({ postId: 'post-1' });

    await expect(service.toggleSave(me, 'post-1')).resolves.toEqual({ saved: true });
    await expect(service.toggleSave(me, 'post-1')).resolves.toEqual({ saved: false });
    expect(prisma.communityPostSave.delete).toHaveBeenCalled();
  });

  it('restricts the following feed to followed profiles and the viewer', async () => {
    prisma.communityPost.findMany.mockResolvedValue([]);
    prisma.communityPost.count.mockResolvedValue(0);

    await service.feed(me, { page: 1, pageSize: 20, scope: 'following' });

    expect(prisma.communityPost.findMany.mock.calls[0][0].where).toEqual({
      academyId: 'academy-1',
      author: { OR: [{ id: 'me' }, { followers: { some: { followerId: 'me' } } }] },
    });
  });

  it('ranks explore by engagement and keeps the ranked order', async () => {
    const recent = new Date();
    prisma.communityPost.findMany
      .mockResolvedValueOnce([
        { id: 'quiet', createdAt: recent, _count: { likes: 0, comments: 0 } },
        { id: 'popular', createdAt: recent, _count: { likes: 9, comments: 4 } },
      ])
      .mockResolvedValueOnce([postRow({ id: 'quiet' }), postRow({ id: 'popular' })]);

    const page = await service.explore(me, { page: 1, pageSize: 20 });

    expect(page.items.map((item) => item.id)).toEqual(['popular', 'quiet']);
    expect(page.total).toBe(2);
  });
});
